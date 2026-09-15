#!/usr/bin/env bash
set -euo pipefail

# Issue, renew and install the denisqsound.tech certificate for the shared
# Oracle edge. Runs on the host as root. Modelled on renew-cert-mskicc.sh:
# certbot --standalone on the `edge` network answers HTTP-01 through the
# proxy_pass in conf.d/54-denisqsound-http.conf.
DOMAINS=(denisqsound.tech www.denisqsound.tech)
CERT_NAME=denisqsound.tech
EDGE_DIR="${EDGE_DIR:-/opt/edge-proxy}"
LE_DIR="${LE_DIR:-${EDGE_DIR}/letsencrypt}"
CERTS_DIR="${CERTS_DIR:-${EDGE_DIR}/certs}"
EDGE_CONTAINER="${EDGE_CONTAINER:-edge-proxy}"
EDGE_NETWORK="${EDGE_NETWORK_NAME:-edge}"
CERTBOT_IMAGE="${CERTBOT_IMAGE:-certbot/certbot:latest}"
CONTAINER_NAME=denisqsound-certbot
ACME_EMAIL="${ACME_EMAIL:-}"
CERT_GROUP="${CERT_GROUP:-wallarm-edge}"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: must run as root (writes under ${EDGE_DIR})" >&2
  exit 1
fi

if ! getent group "${CERT_GROUP}" >/dev/null; then
  echo "ERROR: certificate group ${CERT_GROUP} does not exist" >&2
  exit 1
fi

mkdir -p "${LE_DIR}/etc" "${LE_DIR}/lib"
install -d -o root -g "${CERT_GROUP}" -m 0750 "${CERTS_DIR}"

certbot_args=(
  certonly
  --standalone
  --http-01-port 80
  --cert-name "${CERT_NAME}"
  --key-type ecdsa
  --keep-until-expiring
  --non-interactive
  --agree-tos
)
for domain in "${DOMAINS[@]}"; do
  certbot_args+=(-d "${domain}")
done
if [ -n "${ACME_EMAIL}" ]; then
  certbot_args+=(-m "${ACME_EMAIL}")
else
  certbot_args+=(--register-unsafely-without-email)
fi

echo "==> certbot ${CERT_NAME} (standalone via ${EDGE_CONTAINER} on network ${EDGE_NETWORK})"
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
docker run --rm \
  --name "${CONTAINER_NAME}" \
  --network "${EDGE_NETWORK}" \
  -v "${LE_DIR}/etc:/etc/letsencrypt" \
  -v "${LE_DIR}/lib:/var/lib/letsencrypt" \
  "${CERTBOT_IMAGE}" "${certbot_args[@]}"

LIVE_DIR="${LE_DIR}/etc/live/${CERT_NAME}"
if [ ! -s "${LIVE_DIR}/fullchain.pem" ] || [ ! -s "${LIVE_DIR}/privkey.pem" ]; then
  echo "ERROR: ${LIVE_DIR} has no usable certificate" >&2
  exit 1
fi

echo "==> Install certificate into ${CERTS_DIR}"
install -o root -g root -m 0644 "${LIVE_DIR}/fullchain.pem" "${CERTS_DIR}/denisqsound.crt"
install -o root -g "${CERT_GROUP}" -m 0640 "${LIVE_DIR}/privkey.pem" "${CERTS_DIR}/denisqsound.key"

echo "==> Reload ${EDGE_CONTAINER}"
docker exec "${EDGE_CONTAINER}" nginx -t
docker exec "${EDGE_CONTAINER}" nginx -s reload

openssl x509 -in "${CERTS_DIR}/denisqsound.crt" -noout -subject -dates -ext subjectAltName
