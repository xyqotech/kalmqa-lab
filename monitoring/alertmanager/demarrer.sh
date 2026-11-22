#!/bin/sh
# Écrit la configuration d'Alertmanager à partir de l'environnement, puis le lance.
#
# Alertmanager reçoit les alertes de Prometheus, les regroupe et prévient quelqu'un.
# Il ne sait pas lire une variable d'environnement dans son fichier de configuration.
# Plutôt que de recopier une clé d'envoi dans un second fichier, ce script reprend
# le réglage SMTP de l'application et fabrique la configuration au démarrage, dans
# un dossier que seul ce conteneur voit.
#
#   ALERT_EMAIL_TO    l'adresse prévenue. Vide : aucun e-mail ne part, les alertes
#                     se lisent dans l'interface (port 9093).
#   SMTP_URL          smtps://utilisateur:motdepasse@hote:465 ou smtp://…@hote:587
#   MAIL_FROM         l'expéditeur, le même que pour l'application
#   ALERT_EMAIL_FROM  facultatif : un autre expéditeur pour les alertes
set -eu
umask 077

dossier=/tmp/alertmanager-conf
mkdir -p "$dossier"
conf="$dossier/alertmanager.yml"

cat > "$conf" <<'CONF'
route:
  receiver: destinataire
  # Un e-mail par alerte, et non un par mesure qui la déclenche.
  group_by: [alertname]
  # Attendre 30 s avant le premier e-mail : les alertes qui arrivent ensemble
  # partent ensemble.
  group_wait: 30s
  group_interval: 5m
  # Une alerte qui dure est rappelée deux fois par jour, pas toutes les minutes.
  repeat_interval: 12h

# Quand la base ne répond plus, Ytosign ne répond plus non plus : c'est la même
# panne. On ne garde que l'alerte qui en dit la cause.
inhibit_rules:
  - source_matchers: ['alertname="PostgresInjoignable"']
    target_matchers: ['alertname="YtosignInjoignable"']

CONF

if [ -n "${ALERT_EMAIL_TO:-}" ] && [ -n "${SMTP_URL:-}" ]; then
  # smtps://utilisateur:motdepasse@hote:port → les quatre morceaux.
  reste=${SMTP_URL#*://}
  identifiants=${reste%@*}
  hote=${reste##*@}
  hote=${hote%%/*}
  hote=${hote%%\?*}
  case "$hote" in
    *:*) ;;
    *) hote="$hote:587" ;;
  esac
  # Sur le port 465 la connexion est chiffrée dès le premier octet : il n'y a pas
  # de passage au chiffrement (STARTTLS) à exiger. Sur les autres ports, on l'exige.
  case "$hote" in
    *:465) exiger_starttls=false ;;
    *) exiger_starttls=true ;;
  esac
  printf '%s' "${identifiants#*:}" > "$dossier/smtp-motdepasse"

  cat >> "$conf" <<CONF
global:
  smtp_smarthost: '$hote'
  smtp_from: '${ALERT_EMAIL_FROM:-${MAIL_FROM:-}}'
  smtp_auth_username: '${identifiants%%:*}'
  smtp_auth_password_file: $dossier/smtp-motdepasse
  smtp_require_tls: $exiger_starttls

receivers:
  - name: destinataire
    email_configs:
      - to: '$ALERT_EMAIL_TO'
        # Un second e-mail quand l'alerte se referme : on sait que c'est fini.
        send_resolved: true
        headers:
          Subject: '{{ if eq .Status "firing" }}ALERTE{{ else }}RÉSOLU{{ end }} · {{ .CommonLabels.alertname }} · {{ .CommonAnnotations.summary }}'
CONF
  echo "Alertmanager : les alertes partent par e-mail."
else
  cat >> "$conf" <<'CONF'
# Aucun envoi configuré : les alertes arrivent ici et se lisent dans l'interface.
receivers:
  - name: destinataire
CONF
  echo "Alertmanager : aucun e-mail configuré, les alertes se lisent dans l'interface."
fi

# Une seule instance : pas de dialogue entre plusieurs Alertmanager.
exec /bin/alertmanager \
  --config.file="$conf" \
  --storage.path=/alertmanager \
  --cluster.listen-address=
