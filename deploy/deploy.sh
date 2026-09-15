#!/usr/bin/env bash
set -euo pipefail

# denisqsound.tech deploy: local arm64 build → image over ssh → container
# restart → edge-proxy vhost refresh.
#
# Usage:
#   ./deploy/deploy.sh            # build, ship, restart, refresh edge conf
#   DEPLOY_HOST=other ./deploy/deploy.sh
#   TAG=v1 ./deploy/deploy.sh     # override image tag (default: git short sha)

HOST="${DEPLOY_HOST:-oracle}"
IMAGE="denisqsound-web"
TAG="${TAG:-$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"
REMOTE_DIR="/opt/denisqsound"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "${ROOT_DIR}"

echo "==> Build ${IMAGE}:${TAG} (linux/arm64)"
docker build --platform linux/arm64 -t "${IMAGE}:${TAG}" .

echo "==> Ship image to ${HOST}"
docker save "${IMAGE}:${TAG}" | gzip | ssh "${HOST}" "gunzip | docker load"

echo "==> Install unit files to ${HOST}:${REMOTE_DIR}"
ssh "${HOST}" "sudo mkdir -p ${REMOTE_DIR}/edge-proxy"
for f in compose.yml setup-edge.sh renew-cert-denisqsound.sh; do
  ssh "${HOST}" "sudo tee ${REMOTE_DIR}/${f} >/dev/null" < "deploy/${f}"
done
for f in deploy/edge-proxy/*.conf; do
  ssh "${HOST}" "sudo tee ${REMOTE_DIR}/edge-proxy/$(basename "${f}") >/dev/null" < "${f}"
done

echo "==> Restart container (TAG=${TAG})"
ssh "${HOST}" "cd ${REMOTE_DIR} && sudo TAG=${TAG} docker compose up -d"

echo "==> Refresh edge-proxy vhost"
ssh "${HOST}" "sudo bash ${REMOTE_DIR}/setup-edge.sh"

echo "==> Deployed ${IMAGE}:${TAG} → https://denisqsound.tech"
