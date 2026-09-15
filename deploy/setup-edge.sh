#!/usr/bin/env bash
set -euo pipefail

# Install or refresh the denisqsound.tech vhosts on the shared edge-proxy.
# Runs on the oracle host as root (via `sudo bash setup-edge.sh`).
#
# Order matters:
#   1. the :80 vhost goes in first so ACME challenges can be answered
#   2. the certificate is issued if missing
#   3. the TLS vhost goes in last — installing it without the cert would
#      fail `nginx -t` and could wedge reloads for every site on the proxy
#
# Safe to re-run: nginx is only reloaded after a successful config test.

EDGE_DIR="${EDGE_DIR:-/opt/edge-proxy}"
SITE_DIR="${SITE_DIR:-/opt/denisqsound}"
CONF_D="${EDGE_DIR}/conf.d"
CERT="${EDGE_DIR}/certs/denisqsound.crt"
EDGE_CONTAINER="${EDGE_CONTAINER:-edge-proxy}"

reload_edge() {
  docker exec "${EDGE_CONTAINER}" nginx -t
  docker exec "${EDGE_CONTAINER}" nginx -s reload
  echo "==> ${EDGE_CONTAINER} reloaded"
}

echo "==> Install :80 vhost (ACME + HTTPS redirect)"
install -o root -g root -m 0644 \
  "${SITE_DIR}/edge-proxy/54-denisqsound-http.conf" "${CONF_D}/"
reload_edge

if [ ! -s "${CERT}" ]; then
  echo "==> No certificate at ${CERT}, issuing via certbot (needs live DNS)"
  bash "${SITE_DIR}/renew-cert-denisqsound.sh"
fi

echo "==> Install TLS vhost"
install -o root -g root -m 0644 \
  "${SITE_DIR}/edge-proxy/55-denisqsound.conf" "${CONF_D}/"
reload_edge

echo "==> Edge setup complete"
