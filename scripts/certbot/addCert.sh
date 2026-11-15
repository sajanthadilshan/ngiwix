#!/usr/bin/env bash
# Issue a certificate for one (or more) nginx configs and switch them to HTTPS.
# Usage: 3-add-cert.sh <config-name> [<config-name> ...]
#        3-add-cert.sh --all
# <config-name> is the file name in nginx/conf.d without .conf (app1 -> nginx/conf.d/app1.conf).
# Extra certbot flags can be passed via env, e.g. CERTBOT_EXTRA_ARGS="--staging" to test without rate limits.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../nginx/common.sh"

[[ $# -ge 1 ]] || { usage; exit 1; }
[[ "$1" != "-h" && "$1" != "--help" ]] || { usage; exit 0; }

require_docker
require_nginx
[[ -f "$ENV_FILE" ]] || die "certbot is not set up yet - run installCertbot.sh first"
# shellcheck disable=SC1090
source "$ENV_FILE"
: "${CERTBOT_EMAIL:?CERTBOT_EMAIL missing in config.env}"

# Several configs: run this script once per config so one failure doesn't stop the rest
if [[ $# -gt 1 || "$1" == "--all" ]]; then
  if [[ "$1" == "--all" ]]; then
    mapfile -t names < <(find "$CONF_DIR" -maxdepth 1 -name '*.conf' -printf '%f\n' | sed 's/\.conf$//' | sort)
  else
    names=("$@")
  fi
  [[ ${#names[@]} -gt 0 ]] || die "no configs found in $CONF_DIR"
  rc=0
  for n in "${names[@]}"; do "$SCRIPT_DIR/../certbot/addCert.sh" "$n" || rc=1; done
  exit $rc
fi

name="$(norm_name "$1")"
conf="$CONF_DIR/$name.conf"
bak="$BACKUP_DIR/$name.conf.http"

[[ -f "$conf" ]] || die "no such config: $conf"
if [[ -f "$bak" ]]; then log "$name: SSL already enabled, nothing to do"; exit 0; fi

if grep -Eq '^[[:space:]]*listen[[:space:]].*443' "$conf"; then
  die "$name: already listens on 443 - refusing to modify it"
fi
servers="$(grep -Ec '^[[:space:]]*server[[:space:]]*\{' "$conf" || true)"
[[ "$servers" -eq 1 ]] || die "$name: expected exactly one server { } block, found $servers"

declare -a domains
mapfile -t domains < <(server_names "$conf")
[[ ${#domains[@]} -gt 0 ]] || die "$name: no usable server_name (wildcards and _ are not supported)"
primary="${domains[0]}"

# 1. make sure the HTTP server answers ACME challenges
if ! grep -q '\.well-known/acme-challenge' "$conf"; then
  log "$name: adding ACME challenge location"
  acme='    location ^~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri =404;
    }'
  tmp="$(mktemp)"
  insert_after_server_name "$acme" < "$conf" > "$tmp"
  cat "$tmp" > "$conf"; rm -f "$tmp"
fi
nginx_reload >/dev/null

# 2. issue the certificate (non-interactive)
log "$name: requesting certificate for ${domains[*]}"
args=(certonly --webroot -w /var/www/certbot --cert-name "$primary"
      --email "$CERTBOT_EMAIL" --agree-tos --no-eff-email --non-interactive --expand)
for d in "${domains[@]}"; do args+=(-d "$d"); done
# shellcheck disable=SC2086
run_certbot "${args[@]}" ${CERTBOT_EXTRA_ARGS:-}

# 3. switch the config to HTTPS, roll back if nginx refuses it
mkdir -p "$BACKUP_DIR"
cp -p "$conf" "$bak"
tmp="$(mktemp)"
build_ssl_conf "$bak" "$primary" > "$tmp"
cat "$tmp" > "$conf"; rm -f "$tmp"; chmod 644 "$conf"

if ! nginx_reload; then
  warn "$name: nginx rejected the new config - rolling back"
  cp "$bak" "$conf"; rm -f "$bak"
  nginx_reload || true
  die "$name: SSL not enabled (the certificate itself was issued and is kept)"
fi

log "$name: HTTPS enabled -> https://$primary"