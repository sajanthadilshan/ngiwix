#!/usr/bin/env bash
# Set up certbot for this nginx: pulls the image, stores your email, installs the renewal cron job.
# Usage: 2-setup-certbot.sh --email you@example.com [--all]
#   --email   contact address for Let's Encrypt (remembered in config.env; env CERTBOT_EMAIL also works)
#   --all     also issue certificates for every config in nginx/conf.d right now
# Fully non-interactive.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../nginx/common.sh"

email="${CERTBOT_EMAIL:-}"; do_all=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --email) email="${2:?--email needs a value}"; shift 2 ;;
    --all)   do_all=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done
if [[ -z "$email" && -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"; email="${CERTBOT_EMAIL:-}"
fi
[[ -n "$email" ]] || die "email required: 2-setup-certbot.sh --email you@example.com"

require_docker
require_nginx
mkdir -p "$CERTBOT_DIR"/{www,conf,logs}

printf 'CERTBOT_EMAIL=%q\n' "$email" > "$ENV_FILE"
chmod 600 "$ENV_FILE"

log "Pulling $CERTBOT_IMAGE"
docker pull -q "$CERTBOT_IMAGE" >/dev/null
run_certbot --version

chmod +x "$SCRIPT_DIR"/../certbot/*.sh
log "Installing renewal cron job (03:00 and 15:00 daily)"
install_cron

log "Certbot is ready. Cron entry:"
crontab -l | grep -F "$CRON_MARK"

if [[ $do_all -eq 1 ]]; then
  "$SCRIPT_DIR/../certbot/addCert.sh" --all
else
  echo "Next: ./scripts/addCert.sh <config-name>   (e.g. app1 for nginx/conf.d/app1.conf)"
fi


