#!/usr/bin/env bash
# Called by cron (installed by 2-setup-certbot.sh). Renews certificates that expire within 30 days, then reloads nginx.
set -euo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
source "$(dirname "${BASH_SOURCE[0]}")/../nginx/common.sh"

echo "[$(date -Is)] checking certificates"
run_certbot renew --quiet
docker exec "$NGINX_CONTAINER" nginx -t
docker exec "$NGINX_CONTAINER" nginx -s reload
echo "[$(date -Is)] done"