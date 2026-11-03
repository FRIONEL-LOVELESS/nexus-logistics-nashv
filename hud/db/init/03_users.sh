#!/bin/bash
# Creates two least-privilege MySQL users on first container start:
#   HUD_RW_USER  - used only by the password-protected admin pages (SELECT/INSERT/UPDATE/DELETE on HUD tables)
#   HUD_RO_USER  - used by the public HUD page and /api/feed.cfm (SELECT on the v_public_* views only)
# The mysql:8 entrypoint sources this file after 01_schema.sql and 02_seed.sql.
# Runs in a subshell so its settings do not leak into the entrypoint.
(
  set -eu
  for v in MYSQL_ROOT_PASSWORD MYSQL_DATABASE HUD_RW_USER HUD_RW_PASSWORD HUD_RO_USER HUD_RO_PASSWORD; do
    if [ -z "${!v:-}" ]; then echo "03_users.sh: $v is not set" >&2; exit 1; fi
  done
  # Keep the SQL below injection-proof: names are [A-Za-z0-9_], passwords are [A-Za-z0-9_-.@%+=] only.
  for v in MYSQL_DATABASE HUD_RW_USER HUD_RO_USER; do
    if ! [[ "${!v}" =~ ^[A-Za-z0-9_]{1,32}$ ]]; then echo "03_users.sh: $v must match [A-Za-z0-9_]{1,32}" >&2; exit 1; fi
  done
  for v in HUD_RW_PASSWORD HUD_RO_PASSWORD; do
    if ! [[ "${!v}" =~ ^[A-Za-z0-9_.@%+=-]{16,128}$ ]]; then echo "03_users.sh: $v must be 16-128 chars of [A-Za-z0-9_.@%+=-]" >&2; exit 1; fi
  done
  DB="$MYSQL_DATABASE"
  mysql --protocol=socket -uroot -p"$MYSQL_ROOT_PASSWORD" <<SQL
CREATE USER IF NOT EXISTS '${HUD_RW_USER}'@'%' IDENTIFIED BY '${HUD_RW_PASSWORD}';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`${DB}\`.variants        TO '${HUD_RW_USER}'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`${DB}\`.sectors_or_orgs TO '${HUD_RW_USER}'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`${DB}\`.items           TO '${HUD_RW_USER}'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`${DB}\`.status_events   TO '${HUD_RW_USER}'@'%';

CREATE USER IF NOT EXISTS '${HUD_RO_USER}'@'%' IDENTIFIED BY '${HUD_RO_PASSWORD}';
GRANT SELECT ON \`${DB}\`.v_public_variants TO '${HUD_RO_USER}'@'%';
GRANT SELECT ON \`${DB}\`.v_public_orgs     TO '${HUD_RO_USER}'@'%';
GRANT SELECT ON \`${DB}\`.v_public_items    TO '${HUD_RO_USER}'@'%';
GRANT SELECT ON \`${DB}\`.v_public_events   TO '${HUD_RO_USER}'@'%';
FLUSH PRIVILEGES;
SQL
  echo "03_users.sh: created ${HUD_RW_USER} (admin, table DML) and ${HUD_RO_USER} (read-only, public views)"
)
