#!/usr/bin/env bash
# Run on the MANUALLY created Ubuntu 24.04 x86_64 bootstrap instance.
set -euo pipefail
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg git unzip
curl -fsSL https://apt.releases.hashicorp.com/gpg \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
. /etc/os-release
printf 'deb [arch=%s signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com %s main\n' \
  "$(dpkg --print-architecture)" "${UBUNTU_CODENAME:-$VERSION_CODENAME}" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
sudo apt-get update
sudo apt-get install -y terraform
terraform version
