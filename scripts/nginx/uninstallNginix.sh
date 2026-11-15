#!/usr/bin/env bash
# Uninstall nginx: stops and removes the nginx container and network, removes the renewal cron job,
# and removes the nginx and certbot Docker images.
# By default your configs and certificates stay on disk, so you can reinstall later with 1-install-nginx.sh.
# Usage: 6-uninstall-nginx.sh [-y] [--purge]
#   -y        do not ask for confirmation
#   --purge   ALSO delete nginx/, certbot/ (certificates!), docker-compose.yml and config.env
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

NGINX_IMAGE="${NGINX_IMAGE:-nginx:1.28-alpine}"
assume_yes=0; purge=0
for a in "$@"; do
  case "$a" in
    -y|--yes) assume_yes=1 ;;
    --purge)  purge=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $a" ;;
  esac
done

require_docker

if [[ $assume_yes -ne 1 ]]; then
  msg="Remove the nginx container, cron job and images?"
  [[ $purge -eq 1 ]] && msg="Remove the nginx container AND DELETE all configs and certificates?"
  read -r -p "$msg [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "aborted"; exit 1; }
fi

# 1. container + network
if [[ -f "$ROOT/docker-compose.yml" ]]; then
  log "stopping and removing the nginx container"
  ( cd "$ROOT" && docker compose down --remove-orphans )
else
  docker rm -f "$NGINX_CONTAINER" >/dev/null 2>&1 && log "removed container $NGINX_CONTAINER" || true
fi

# 2. cron job (renewal is pointless without nginx)
remove_cron

# 3. data (files created by Docker are root-owned, so delete them from inside a container)
if [[ $purge -eq 1 ]]; then
  log "deleting configs, certificates and compose file"
  docker run --rm --entrypoint sh -v "$ROOT:/d" "$NGINX_IMAGE" \
    -c 'rm -rf /d/nginx /d/certbot /d/docker-compose.yml /d/config.env'
fi

# 4. images
for img in "$NGINX_IMAGE" "$CERTBOT_IMAGE"; do
  docker rmi "$img" >/dev/null 2>&1 && log "removed image $img" || true
done

if [[ $purge -eq 1 ]]; then
  log "nginx fully removed. Only the scripts/ folder is left."
else
  log "nginx removed. Configs and certificates are kept in $ROOT (use --purge to delete them)."
fi