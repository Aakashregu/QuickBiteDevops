#!/bin/sh
# Run on APPLICATION server inside /home/ubuntu/quickbite.
set -eu

docker compose config --quiet
docker compose pull
docker compose up -d --force-recreate --remove-orphans --wait --wait-timeout 120
docker compose ps

# These fail the deployment stage if HTTP or the dummy service chain fails.
curl --fail --silent --show-error http://127.0.0.1/health
curl --fail --silent --show-error http://127.0.0.1/api/foods
printf '\n'

container_id=$(docker compose ps -q frontend)
actual_image=$(docker inspect --format '{{.Config.Image}}' "$container_id")
expected_image=$(sed -n 's/^FRONTEND_IMAGE=//p' .env)
printf 'Expected image: %s\nRunning image:  %s\n' "$expected_image" "$actual_image"
[ "$actual_image" = "$expected_image" ]
