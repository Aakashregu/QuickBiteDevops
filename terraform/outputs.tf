output "control_public_ip" {
  description = "Managed DevOps Control Node public IPv4 address"
  value       = aws_instance.control.public_ip
}

output "control_private_ip" {
  value = aws_instance.control.private_ip
}

output "app_public_ip" {
  description = "Open http://THIS_IP in your browser"
  value       = aws_instance.app.public_ip
}

output "app_private_ip" {
  description = "Use this for Ansible, SSH deployment and Jenkins APP_HOST"
  value       = aws_instance.app.private_ip
}

output "db_private_ip" {
  description = "Private MySQL EC2 address; there is deliberately no public IP"
  value       = aws_instance.db.private_ip
}

output "ubuntu_ami_id" {
  value = data.aws_ami.ubuntu.id
}

output "ansible_inventory" {
  description = "Run terraform output -raw ansible_inventory > ../ansible/inventory.ini"
  value = templatefile("${path.module}/inventory.tftpl", {
    control_private_ip = aws_instance.control.private_ip
    app_private_ip     = aws_instance.app.private_ip
    db_private_ip      = aws_instance.db.private_ip
  })
}
