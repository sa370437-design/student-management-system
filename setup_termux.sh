#!/data/data/com.termux/files/usr/bin/bash
# Termux one-click setup for Student Management System

set -euo pipefail

APP_DIR="$HOME/student-management-system"
DB_NAME="freecodeschool"
DB_USER="fcs_admin"
DB_PASSWORD=""
DJANGO_ADMIN_USER="admin"
DJANGO_ADMIN_EMAIL="admin@example.com"
DJANGO_ADMIN_PASSWORD="Admin@12345"

echo "[+] Updating Termux packages..."
pkg update -y && pkg upgrade -y
pkg install -y git python python-pip postgresql libpq clang make libffi openssl

echo "[+] Initializing PostgreSQL..."
PGDATA="$PREFIX/var/lib/postgresql"
mkdir -p "$PGDATA"
if [ ! -f "$PGDATA/PG_VERSION" ]; then
  initdb -D "$PGDATA"
fi
pg_ctl -D "$PGDATA" -l "$PGDATA/server.log" -o "-k $PREFIX/tmp" start
sleep 2

export PGHOST="$PREFIX/tmp"
export PGUSER="$(whoami)"

echo "[+] Cloning repository..."
if [ -d "$APP_DIR" ]; then
  cd "$APP_DIR" && git pull
else
  git clone https://github.com/freecodeschoolindy/student-management-system.git "$APP_DIR"
  cd "$APP_DIR"
fi

echo "[+] Setting up Python venv..."
python -m venv .venv
source .venv/bin/activate
pip install --upgrade pip wheel setuptools
pip install -r requirements.txt || true
pip install psycopg2-binary

echo "[+] Configuring PostgreSQL..."
psql <<SQL
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${DB_USER}') THEN
      CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASSWORD}';
   END IF;
END\$\$;
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_NAME}') THEN
      CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
   END IF;
END\$\$;
SQL

echo "[+] Applying Django migrations..."
python manage.py migrate

echo "[+] Creating Django admin user..."
python <<PY
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE','config.settings')
django.setup()
from django.contrib.auth import get_user_model
User = get_user_model()
u, created = User.objects.get_or_create(username="${DJANGO_ADMIN_USER}", defaults={"email":"${DJANGO_ADMIN_EMAIL}","is_staff":True,"is_superuser":True})
u.set_password("${DJANGO_ADMIN_PASSWORD}")
u.save()
print("Admin user ready: ${DJANGO_ADMIN_USER} / ${DJANGO_ADMIN_PASSWORD}")
PY

echo "[+] Starting Django server at http://0.0.0.0:8000 ..."
python manage.py runserver 0.0.0.0:8000
