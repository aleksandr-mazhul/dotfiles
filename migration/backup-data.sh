#!/usr/bin/env bash
# Back up stateful data that git does not hold and that is NOT secret:
# docker volumes, database dumps, and the hand-made system files from the
# course projects. Needs sudo. Secrets go through backup-secrets.sh instead.
#
# Usage: backup-data.sh <dest-dir>      (dest should be on another disk)
set -euo pipefail

dest="${1:?usage: backup-data.sh <dest-dir>}"
mkdir -p "$dest"
stamp="$(date +%F)"

step() { printf '\n==> %s\n' "$*"; }

step "docker volumes"
if command -v docker >/dev/null; then
  for vol in $(docker volume ls -q); do
    if [ -n "$(docker ps -q --filter "volume=$vol")" ]; then
      echo "skip $vol: a running container uses it (stop it first)"
      continue
    fi
    sudo tar -C "/var/lib/docker/volumes/$vol" -czf "$dest/docker-vol-$vol-$stamp.tgz" _data
    echo "ok   $vol"
  done
fi

step "postgresql"
if systemctl is-active --quiet postgresql; then
  sudo -u postgres pg_dumpall | gzip >"$dest/postgres-all-$stamp.sql.gz"
  echo "ok   pg_dumpall"
else
  echo "skip: postgresql is not running (start it if it holds data you need)"
fi

step "mariadb"
if systemctl is-active --quiet mariadb; then
  sudo mariadb-dump --all-databases | gzip >"$dest/mariadb-all-$stamp.sql.gz"
  echo "ok   mariadb-dump"
else
  echo "skip: mariadb is not running"
fi

step "hand-made system files"
# Units, nginx site, grub defaults and the flask app from the course projects.
sudo tar -czf "$dest/system-files-$stamp.tgz" \
  --exclude='/opt/flaskapp/venv' \
  /etc/systemd/system /etc/nginx /etc/default/grub /etc/fstab /opt/flaskapp 2>/dev/null || true
sudo chown "$(id -u):$(id -g)" "$dest"/*"$stamp"* 2>/dev/null || true
echo "ok   system-files"

step "result"
ls -lh "$dest"
