#!/usr/bin/env bash
# Add a new proxy config (tunnel) and reload nginx gracefully - nginx is never stopped.
# Usage: addConfig.sh <domain> <clientIp> <clientPort> [issuecert]
#   domain      public host name, e.g. app1.example.com
#   clientIp    IP (or host name) of the backend, e.g. 192.168.1.11
#   clientPort  backend port, e.g. 8080
#   issuecert   yes|true|1 = also issue a Let's Encrypt cert and switch to HTTPS (default: no)
# Example: addConfig.sh app1.example.com 192.168.1.11 8080 yes
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

[[ $# -ge 3 && $# -le 4 ]] || { usage; exit 1; }
domain="${1,,}"; ip="$2"; port="$3"; issue="${4:-no}"

# ---- validate input ----
[[ "$domain" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]] || die "invalid domain: $1"
[[ "$ip" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid client IP/host: $ip"
if [[ "$ip" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; then
  IFS=. read -ra o <<<"$ip"
  for x in "${o[@]}"; do (( x <= 255 )) || die "invalid IP address: $ip"; done
fi
[[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )) || die "invalid port: $port"
case "${issue,,}" in
  yes|y|true|1|ssl|cert) do_cert=1 ;;
  no|n|false|0|"")       do_cert=0 ;;
  *) die "issuecert must be yes or no (got: $issue)" ;;
esac

require_docker
require_nginx
conf="$CONF_DIR/$domain.conf"
[[ ! -e "$conf" ]] || die "$conf already exists"
if [[ $do_cert -eq 1 && ! -f "$ENV_FILE" ]]; then
  die "certbot is not set up - run 2-setup-certbot.sh first (or use issuecert=no)"
fi

#write config for nginx.conf.d
cat > "$conf" <<EOF
server {
    listen 80;
    server_name $domain;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files \$uri =404;
    }

    location / {
        proxy_pass http://$ip:$port;
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
chmod 644 "$conf"

# nginix reload
if ! nginx_reload; then
  rm -f "$conf"
  nginx_reload >/dev/null 2>&1 || true
  die "nginx rejected the new config - it was removed again"
fi
# log "added $domain -> $ip:$port (http://$domain)"

#certbot
if [[ $do_cert -eq 1 ]]; then
  "$SCRIPT_DIR/../certbot/addCert.sh" "$domain" \
    || die "config is live on HTTP, but the certificate step failed (check DNS and port 80), then run: 3-add-cert.sh $domain"
fi

echo '{"success": "ok", "data": {}}'