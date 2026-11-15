#!/bin/sh
# Crée le compte réservé à la supervision.
#
# Il reçoit le rôle pg_monitor : il lit les statistiques de Postgres, mais il ne
# peut ni lire ni modifier les données de Ytosign. L'outil de supervision n'a
# donc jamais les clés de la base.
#
# L'image Postgres n'exécute ce script qu'au PREMIER démarrage (volume vide).
# Sur un volume existant, relance-le à la main (il est rejouable sans risque) :
#   docker exec <conteneur db> sh /docker-entrypoint-initdb.d/10-monitoring-role.sh
set -eu

: "${MONITORING_PASSWORD:?MONITORING_PASSWORD manquant : renseigne POSTGRES_MONITORING_PASSWORD dans .env}"

psql -v ON_ERROR_STOP=1 -v pw="$MONITORING_PASSWORD" --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'monitoring') THEN
    CREATE ROLE monitoring LOGIN;
  END IF;
END
$$;
ALTER ROLE monitoring PASSWORD :'pw';
GRANT pg_monitor TO monitoring;
SQL
