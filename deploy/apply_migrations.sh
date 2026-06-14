#!/usr/bin/env bash
# Apply schemas/*.sql to $DATABASE_URL in filename order (the migration history).
# schemas/ is the single source of schema truth (ADR-003 / restructure plan).
#
# Migrations should use IF NOT EXISTS where practical; a hard CREATE that errors
# on re-run is the signal to write the next-numbered migration, not to edit an
# applied one. ON_ERROR_STOP makes any failure abort loudly.
#
#   DATABASE_URL=postgresql://meridian:...@192.168.0.28:5544/meridian \
#       deploy/apply_migrations.sh
set -euo pipefail
: "${DATABASE_URL:?set DATABASE_URL (or source meridian.env first)}"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
shopt -s nullglob
migrations=("$repo_root"/schemas/*.sql)
if [ ${#migrations[@]} -eq 0 ]; then
  echo "no migrations found in $repo_root/schemas/" >&2
  exit 1
fi

for f in "${migrations[@]}"; do
  echo ">>> applying $(basename "$f")"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$f"
done
echo "migrations applied."
