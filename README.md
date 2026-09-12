# QuickBite DevOps PRT starter

A learning-lab implementation for the QuickBite practical assignment. **This is starter code, not evidence of a completed AWS deployment.** Follow [the beginner walkthrough](docs/WALKTHROUGH.md), run each verification, and capture your own screenshots.

## Important interpretations

- Manually create one temporary **bootstrap** EC2 node. Terraform then creates **three managed EC2 nodes**: control, application, and private MySQL. This means **four running instances during setup**. If your instructor means exactly three total, get clarification before creating anything; the current code is not an import-based three-instance design.
- Terraform creates one **custom public route table**. AWS also automatically creates a main route table; the private subnet is explicitly associated with that local-only table.
- The **real MySQL EC2 server** satisfies Tasks 1-2. The Compose `database` service is a clearly labeled, in-memory HTTP **dummy database**, satisfying Task 3. It is NOT MySQL, has no persistence, and is not a replacement for the EC2 MySQL installation.
- Kubernetes is not required by this assignment and is intentionally not used.

## Architecture

```text
Temporary bootstrap (manual EC2, outside the lab VPC)
  Terraform + EC2 instance role
           |
           v
Custom VPC: 10.20.0.0/16
  Public subnet: 10.20.1.0/24
    control: Ansible + Jenkins + Docker builder + restricted APT proxy
    app: Docker Compose [frontend -> backend -> dummy database]
  Private subnet: 10.20.2.0/24
    db: real MySQL Server, no public IP, no Internet default route

Laptop -> app:80                         public webpage
Laptop -> control:22,8080                restricted to laptop public IP /32
Bootstrap -> control:22                 restricted to bootstrap public IP /32
Control -> app:22 and db:22              SSH / Ansible
App -> db:3306                           permitted MySQL traffic
DB -> control:3128 -> Ubuntu repositories  package downloads, not general routing
```

The database uses an APT forward proxy on control instead of a paid NAT Gateway. Both security-group rules and Squid ACLs restrict the proxy; it is not publicly accessible.

## Required choices and credentials

Use Ubuntu Server **24.04 LTS x86_64**, one AWS region, a **public** GitHub lab repository and a **public** Docker Hub repository named `quickbite-frontend`.

The deployment server intentionally uses anonymous image pulls. **A private Docker Hub repository will make deployment fail** unless you add a separate secure read-only registry credential on that server. Do not put registry tokens in this repository or in `.env`.

- AWS: an EC2 instance role on bootstrap, not hard-coded AWS keys.
- Terraform SSH key: `~/.ssh/quickbite_lab`, generated on bootstrap; its public half is imported into AWS.
- Jenkins-only app SSH key: `~/.ssh/quickbite_deploy`, generated on managed control **before Ansible**; Ansible adds its public half to app only.
- Jenkins credential `app-server-ssh`: SSH username `ubuntu` and the private **deployment** key.
- Jenkins credential `dockerhub-creds`: Docker Hub username and a write-capable Docker Hub access token.
- `Jenkinsfile`: replace `DOCKERHUB_NAMESPACE` and `APP_HOST` with your username and **application private IP**.

## Essential sequence

1. Upload the non-secret starter source to GitHub.
2. Create bootstrap manually; attach its EC2 provisioning role and restrict SSH.
3. Clone this repo on bootstrap; install Terraform using `scripts/install-bootstrap.sh`.
4. Generate the lab SSH key, set `terraform/terraform.tfvars`, and run init, validate, plan and apply.
5. Generate inventory using the Terraform output. Transfer that inventory and the main lab key to managed control.
6. On managed control, clone the repo, install Ansible, verify app/DB SSH host-key fingerprints, and generate the separate deployment key.
7. Run `ansible-playbook site.yml` from `ansible/` on **managed control**, not bootstrap. Reconnect your shell afterward for Docker group membership.
8. Perform the initial manual Docker deployment as below.
9. Unlock Jenkins, install the required plugins, add credentials, and configure Pipeline from SCM.
10. Build, inspect the numbered registry tag, modify the frontend, push, build again, and verify the visible change.

See `docs/WALKTHROUGH.md` for exact commands and expected results. **Do not jump straight to `docker compose up`.**

## Initial manual deployment handoff

After copying `Dockerfile`, `docker-compose.yml`, `frontend/`, `backend/` and `database/` to `/home/ubuntu/quickbite` on **app**, run there:

```bash
cd /home/ubuntu/quickbite
docker build -t quickbite-frontend:manual .
printf 'FRONTEND_IMAGE=quickbite-frontend:manual\n' > .env
docker compose config
docker compose up -d --wait --wait-timeout 120
docker compose ps
```

Compose deliberately references an image rather than defining `build:`. Manual setup builds `quickbite-frontend:manual` locally. Jenkins later builds on control, tags and pushes `YOUR_USER/quickbite-frontend:BUILD_NUMBER`, writes that image name into app's `.env`, and pulls/recreates the services there. The manual image is not pushed to Docker Hub.

All three services have `restart: unless-stopped`; Ansible enables Docker at boot. Backend and dummy database publish no host ports. Their Python source is copied alongside Compose; only the frontend is a custom-built image, as required by the exercise.

## Jenkins stages

`Checkout -> Build -> Tag -> Push -> Deploy`

Required plugins: Git, Docker, Pipeline, SSH Agent, Credentials Binding. Pipeline: Stage View is useful for evidence. Docker Pipeline is optional; this Jenkinsfile uses Docker CLI commands rather than Docker Pipeline-specific steps. Use `Build Now`; the paper does not require a public webhook endpoint. Builds run on the controller only for this trusted, single-student lab; production systems should use isolated build agents.

## Safety and limits

- AWS compute, disks and public IPv4 addresses can incur charges. Do not assume this is free. No NAT Gateway or Kubernetes cluster is created.
- HTTP on ports 80/8080 is for a temporary demonstration. Restrict Jenkins/SSH, use unique throwaway lab credentials, and never handle real customer data. Prefer the guide's SSH tunnel for the Jenkins UI.
- Docker-group membership is effectively root-level access. Use only your trusted repository; do not run untrusted pull requests.
- Never commit private keys, tokens, Terraform state, saved plans, generated inventory or real `.tfvars`. Keep `.gitignore`; commit `.terraform.lock.hcl` once generated.
- A VM reboot triggers Docker restart policies. A deliberately stopped container stays stopped until started again. A failed health check alone does not automatically restart a running container.
- This deployment is single-instance, has brief redeploy downtime, floating base-image tags, no production database integration, no TLS/backup/HA, and no automatic rollback. It demonstrates the specified practical, not a production food-delivery system.
- Local checks and their limits are recorded in `docs/LOCAL-CHECKS.md`. AWS provisioning and CI/CD execution still need to be performed by the student.
- Save evidence first, then use `terraform destroy` on bootstrap and separately remove the manually created bootstrap resources. See the guide's cleanup section.
