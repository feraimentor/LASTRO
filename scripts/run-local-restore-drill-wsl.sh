#!/usr/bin/env bash
set -euo pipefail

source_database="${1:-lastro_verify}"
restore_database="${2:-lastro_restore_drill}"
artifact="/tmp/${restore_database}.dump"

sudo pg_ctlcluster 16 main start >/dev/null 2>&1 || true
until pg_isready -q; do sleep 1; done
sudo -u postgres pg_dump --format=custom --compress=9 --no-owner --no-acl --file="$artifact" "$source_database"
sudo -u postgres dropdb --if-exists "$restore_database"
sudo -u postgres createdb "$restore_database"
started="$(date +%s)"
sudo -u postgres pg_restore --no-owner --no-acl --exit-on-error --dbname="$restore_database" "$artifact"
finished="$(date +%s)"
legal="$(sudo -u postgres psql -Atqc "select count(*) from public.legal_document_versions where state='published' and is_current" "$restore_database")"
rls="$(sudo -u postgres psql -Atqc "select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and not c.relrowsecurity" "$restore_database")"
views="$(sudo -u postgres psql -Atqc "select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='v' and not coalesce(c.reloptions,'{}'::text[]) @> array['security_invoker=true']" "$restore_database")"
objects="$(sudo -u postgres psql -Atqc "select count(*) from storage.objects" "$restore_database")"
checksum="$(sha256sum "$artifact" | cut -d' ' -f1)"

if [[ "$legal" != "3" || "$rls" != "0" || "$views" != "0" ]]; then
  echo "RESTORE_DRILL_FAILED legal_current=$legal rls_missing=$rls unsafe_views=$views" >&2
  exit 1
fi
echo "RESTORE_DRILL_OK legal_current=$legal rls_missing=$rls unsafe_views=$views storage_objects=$objects rto_seconds=$((finished-started)) sha256=$checksum"
