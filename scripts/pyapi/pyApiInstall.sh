#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$ROOT"

#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$ROOT"

case "$1" in
  --stop)
    docker compose stop python-api
    ;;
  --uninstall)
    docker compose rm -sf python-api
    ;;
  *)
    docker compose up -d --build python-api
    docker compose logs -f python-api
    ;;
esac