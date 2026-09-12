#!/usr/bin/env bash
# Jenkins supplies an SSH agent and the two arguments. Run from repository root.
set -euo pipefail
app_host=${1:?Usage: deploy.sh APP_PRIVATE_IP IMAGE_WITH_BUILD_TAG}
image=${2:?Supply namespace/quickbite-frontend:BUILD_NUMBER}
remote="ubuntu@${app_host}"
ssh_options=(-o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=20)

env_file=$(mktemp)
trap 'rm -f "$env_file"' EXIT
printf 'FRONTEND_IMAGE=%s\n' "$image" > "$env_file"

ssh "${ssh_options[@]}" "$remote" 'mkdir -p /home/ubuntu/quickbite'
scp "${ssh_options[@]}" -r docker-compose.yml backend database \
  "$remote:/home/ubuntu/quickbite/"
scp "${ssh_options[@]}" scripts/remote-deploy.sh \
  "$remote:/home/ubuntu/quickbite/remote-deploy.sh"
scp "${ssh_options[@]}" "$env_file" "$remote:/home/ubuntu/quickbite/.env"
ssh "${ssh_options[@]}" "$remote" \
  'cd /home/ubuntu/quickbite && sh ./remote-deploy.sh'
