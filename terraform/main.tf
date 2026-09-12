data "aws_availability_zones" "available" {
  state = "available"
}

# Canonical's official Ubuntu 24.04 LTS, x86_64, EBS-backed AMI.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_vpc" "quickbite" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "quickbite-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.quickbite.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "quickbite-public" }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.quickbite.id
  cidr_block              = "10.20.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags                    = { Name = "quickbite-private" }
}

resource "aws_internet_gateway" "quickbite" {
  vpc_id = aws_vpc.quickbite.id
  tags   = { Name = "quickbite-igw" }
}

# The ONE custom route table required by the brief.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.quickbite.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.quickbite.id
  }
  tags = { Name = "quickbite-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# AWS automatically creates a main route table with the VPC-local route.
# Leave it without an Internet default route; explicitly associate private here.
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_vpc.quickbite.default_route_table_id
}

# Rules are separate resources to avoid circular security-group dependencies.
resource "aws_security_group" "control" {
  name_prefix = "quickbite-control-"
  description = "Control SSH, restricted Jenkins, and DB-only APT proxy"
  vpc_id      = aws_vpc.quickbite.id
  tags        = { Name = "quickbite-control-sg" }
}

resource "aws_security_group" "app" {
  name_prefix = "quickbite-app-"
  description = "Public HTTP and SSH only from the control node"
  vpc_id      = aws_vpc.quickbite.id
  tags        = { Name = "quickbite-app-sg" }
}

resource "aws_security_group" "db" {
  name_prefix = "quickbite-db-"
  description = "MySQL only from app; management SSH only from control"
  vpc_id      = aws_vpc.quickbite.id
  tags        = { Name = "quickbite-db-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "control_ssh" {
  for_each = {
    administrator = var.admin_cidr
    bootstrap     = var.bootstrap_cidr
  }
  security_group_id = aws_security_group.control.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  description       = "SSH from ${each.key} only"
}

resource "aws_vpc_security_group_ingress_rule" "jenkins" {
  security_group_id = aws_security_group.control.id
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
  description       = "Jenkins UI from administrator only"
}

resource "aws_vpc_security_group_ingress_rule" "apt_proxy" {
  security_group_id            = aws_security_group.control.id
  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 3128
  to_port                      = 3128
  description                  = "Private DB downloads packages through control"
}

resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  description       = "Public QuickBite webpage"
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.control.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  description                  = "SSH from managed control only"
}

resource "aws_vpc_security_group_ingress_rule" "db_ssh" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.control.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  description                  = "Ansible management from managed control only"
}

resource "aws_vpc_security_group_ingress_rule" "mysql" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  description                  = "MySQL from application server only"
}

resource "aws_vpc_security_group_egress_rule" "outbound" {
  for_each = {
    control = aws_security_group.control.id
    app     = aws_security_group.app.id
    db      = aws_security_group.db.id
  }
  security_group_id = each.value
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Lab outbound; routing still isolates the private subnet"
}

resource "aws_key_pair" "lab" {
  key_name   = "quickbite-lab-key"
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

resource "aws_instance" "control" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.control_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.control.id]
  key_name                    = aws_key_pair.lab.key_name
  associate_public_ip_address = true

  metadata_options { http_tokens = "required" }
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
  tags       = { Name = "quickbite-control" }
  depends_on = [aws_route_table_association.public]
}

resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.app_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = aws_key_pair.lab.key_name
  associate_public_ip_address = true

  metadata_options { http_tokens = "required" }
  root_block_device {
    volume_size           = 12
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
  tags       = { Name = "quickbite-app" }
  depends_on = [aws_route_table_association.public]
}

resource "aws_instance" "db" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.db_instance_type
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.db.id]
  key_name                    = aws_key_pair.lab.key_name
  associate_public_ip_address = false

  metadata_options { http_tokens = "required" }
  root_block_device {
    volume_size           = 12
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
  tags = { Name = "quickbite-db" }
}
