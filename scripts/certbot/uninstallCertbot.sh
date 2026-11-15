#!/usr/bin/env bash
# Remove certbot completely: reverts every SSL-enabled config to plain HTTP, removes the cron job,
# deletes all certificates/account data and the certbot image. The nginx container is left running.
# Usage: 4-remove-certbot.sh [-y] [--keep-data]
#   -y          do not ask for confirmation
#   --keep-data keep certbot/ data (certificates, account) on disk
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../nginx/common.sh"

assume_yes=0; keep_data=0
for a in "$@"; do
  case "$a" in
    -y|--yes) assume_yes=1 ;;
    --keep-data) keep_data=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $a" ;;
  esac
done

require_docker

if [[ $assume_yes -ne 1 ]]; then
  read -r -p "Remove certbot, revert all configs to HTTP and delete certificates? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "aborted"; exit 1; }
fi

# 1. revert configs
restored=0
shopt -s nullglob
for bak in "$BACKUP_DIR"/*.conf.http; do
  name="$(basename "$bak" .conf.http)"
  restore_http_config "$name" && { log "reverted $name to HTTP"; restored=$((restored+1)); }
done
shopt -u nullglob

if nginx_running; then
  nginx_reload >/dev/null || die "nginx rejected the reverted configs - fix them, then re-run (nothing deleted yet)"
fi

# 2. cron
remove_cron

# 3. data (contents only: nginx keeps these directories bind-mounted)
if [[ $keep_data -eq 0 && -d "$CERTBOT_DIR" ]]; then
  log "deleting certbot data"
  docker run --rm --entrypoint sh -v "$CERTBOT_DIR:/d" "$CERTBOT_IMAGE" \
    -c 'find /d/conf /d/www /d/logs -mindepth 1 -delete'
fi
rm -f "$ENV_FILE"
rmdir "$BACKUP_DIR" 2>/dev/null || true

# 4. image
docker rmi "$CERTBOT_IMAGE" >/dev/null 2>&1 && log "removed image $CERTBOT_IMAGE" || true

log "certbot removed ($restored config(s) reverted to HTTP)."