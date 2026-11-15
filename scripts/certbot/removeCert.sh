#!/usr/bin/env bash
# Remove HTTPS for one config: restores its HTTP-only version and deletes its certificate.
# Certbot itself and the cron job stay in place for your other configs.
# Usage: 5-remove-cert.sh <config-name> [--keep-cert]
#   --keep-cert   revert the config but keep the certificate files/renewal
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../nginx/common.sh"

[[ $# -ge 1 ]] || { usage; exit 1; }
[[ "$1" != "-h" && "$1" != "--help" ]] || { usage; exit 0; }
name="$(norm_name "$1")"; keep_cert=0
[[ "${2:-}" == "--keep-cert" ]] && keep_cert=1

require_docker
require_nginx
bak="$BACKUP_DIR/$name.conf.http"
[[ -f "$bak" ]] || { log "$name: SSL is not enabled for this config - nothing to do"; exit 0; }

declare -a domains
mapfile -t domains < <(server_names "$bak")
primary="${domains[0]:-}"

# config first, so nginx never points at a certificate that no longer exists
restore_http_config "$name"
nginx_reload >/dev/null || die "$name: nginx rejected the reverted config; certificate NOT deleted"
log "$name: reverted to HTTP"

if [[ $keep_cert -eq 0 && -n "$primary" ]]; then
  run_certbot delete --cert-name "$primary" --non-interactive \
    && log "$name: certificate '$primary' deleted" \
    || warn "$name: could not delete certificate '$primary' (already gone?)"
fi