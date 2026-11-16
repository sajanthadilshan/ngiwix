#!/usr/bin/env bash
# Create the nginx reverse-proxy container. Certbot directories are mounted, but certbot is NOT installed.
# Usage: 1-install-nginx.sh [--install-docker]
#   --install-docker   install Docker via get.docker.com if it is missing
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

install_docker=0
for a in "$@"; do
  case "$a" in
    --install-docker) install_docker=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $a" ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  [[ $install_docker -eq 1 ]] || die "docker is not installed. Re-run with --install-docker, or install it yourself."
  log "Installing Docker (get.docker.com)"
  SUDO=""; [[ $EUID -eq 0 ]] || SUDO="sudo"
  curl -fsSL https://get.docker.com | $SUDO sh
  $SUDO systemctl enable --now docker >/dev/null 2>&1 || true
  if [[ $EUID -ne 0 ]]; then
    $SUDO usermod -aG docker "$USER" || true
    warn "Added $USER to the docker group. If the next step fails, log out/in and re-run this script."
  fi
fi
require_docker

mkdir -p "$CONF_DIR" "$ROOT/nginx/examples" "$CERTBOT_DIR"/{www,conf,logs}

write_if_missing() {   # $1 = path, content on stdin
  if [[ -e "$1" ]]; then warn "${1#"$ROOT"/} already exists, leaving it alone"; cat >/dev/null
  else cat > "$1"; log "created ${1#"$ROOT"/}"; fi
}


write_if_missing "$ROOT/nginx/nginx.conf" <<'EOF'
user nginx;
worker_processes 1;

events {
    worker_connections 4096;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    server_tokens off;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;

    keepalive_timeout 65;
    client_max_body_size 100M;

    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    proxy_buffering off;

    # used by any server block that enables SSL
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    # Catch-all: requests whose Host matches no configured domain (e.g. the bare IP)
    server {
        listen 80 default_server;
        server_name _;
        root /var/www/default;
        location / {
            try_files /index.html =404;
        }
    }

    # HTTPS to the bare IP: refuse the TLS handshake (no certificate exists for an IP)
    server {
        listen 443 ssl default_server;
        ssl_reject_handshake on;
    }

    include /etc/nginx/conf.d/*.conf;
}
EOF

write_if_missing "$ROOT/nginx/examples/app.conf.example" <<'EOF'
# Copy to nginx/conf.d/app1.conf and edit.
# Rules so that 3-add-cert.sh can upgrade it to HTTPS automatically:
#   - exactly ONE server { } block, listening on port 80
#   - a server_name line with real domain name(s)
server {
    listen 80;
    server_name app1.example.com;

    location / {
        proxy_pass http://192.168.1.11:8080;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

log "Starting nginx"
( cd "$ROOT" && docker compose up -d )
sleep 2
if ! nginx_running; then
  docker logs --tail 30 "$NGINX_CONTAINER" || true
  die "nginx container did not start - see log above"
fi
docker exec "$NGINX_CONTAINER" nginx -t

log "nginx is running as '$NGINX_CONTAINER' on ports 80/443."
echo "Next: put a config in nginx/conf.d/ (see nginx/examples/), reload with:"
echo "  docker exec $NGINX_CONTAINER nginx -s reload"
echo "Add HTTPS later with 2-setup-certbot.sh and 3-add-cert.sh."