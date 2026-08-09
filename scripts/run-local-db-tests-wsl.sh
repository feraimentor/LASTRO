#!/usr/bin/env bash
set -euo pipefail

repo="${1:-/mnt/c/Users/brmar/OneDrive/Documentos/ChatGPT/LASTRO}"
database="${2:-lastro_verify}"

sudo pg_ctlcluster 16 main start >/dev/null 2>&1 || true
for attempt in {1..20}; do
  if pg_isready -q; then break; fi
  if [[ "$attempt" == "20" ]]; then echo "PostgreSQL local não ficou pronto." >&2; exit 1; fi
  sleep 1
done

sudo -u postgres dropdb --if-exists "$database"
sudo -u postgres createdb "$database"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$database" -f "$repo/supabase/tests/bootstrap.sql"

for migration in "$repo"/supabase/migrations/*.sql; do
  echo "APPLYING $(basename "$migration")"
  sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$database" -f "$migration"
done

sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$database" -f "$repo/supabase/seed.sql"
for seed in "$repo"/supabase/seeds/*.sql; do
  echo "SEEDING $(basename "$seed")"
  sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$database" -f "$seed"
done
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$database" -f "$repo/supabase/tests/database/rls_and_invariants.test.sql"
