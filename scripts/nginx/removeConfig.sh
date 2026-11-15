#!/usr/bin/env bash
# Remove a proxy config (tunnel), and its certificate if it has one, then reload nginx gracefully.
# Usage: removeConfig.sh <domain> [--keep-cert]
#   --keep-cert   keep the Let's Encrypt certificate files (default: delete them)
# Example: removeConfig.sh app1.example.com
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

[[ $# -ge 1 ]] || { usage; exit 1; }
[[ "$1" != "-h" && "$1" != "--help" ]] || { usage; exit 0; }

domain="$(norm_name "${1,,}")"
keep_cert=""
[[ "${2:-}" == "--keep-cert" ]] && keep_cert="--keep-cert"

require_docker
require_nginx

conf="$CONF_DIR/$domain.conf"
bak="$BACKUP_DIR/$domain.conf.http"
[[ -f "$conf" ]] || die "no such config: $conf"

# 1. If HTTPS is enabled, remove the certificate FIRST. This also restores the HTTP version of the
#    config; doing it after deleting the config would bring the file back.
if [[ -f "$bak" ]]; then
  "$SCRIPT_DIR/../certbot/removeCert.sh" "$domain" $keep_cert \
    || die "removing the certificate failed for $domain - config left in place"
fi

# 2. Delete the config and reload gracefully (nginx keeps running)
rm -f "$conf"
nginx_reload >/dev/null || warn "nginx rejected the config set after removal - check the other files in $CONF_DIR"

# log "removed $domain"
echo '{"success": "ok", "data": {}}'