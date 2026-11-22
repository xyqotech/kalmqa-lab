# La vérification externe : quelqu'un d'autre que le serveur regarde si le site répond.
#
# La supervision installée sur le serveur (Prometheus, Alertmanager) voit tout ce
# qui se passe DANS la machine. Mais si la machine entière s'arrête, elle s'arrête
# avec elle et ne prévient personne. Google visite donc le site de l'extérieur,
# depuis plusieurs régions, et envoie un e-mail quand la visite échoue.
#
# Rien n'est créé tant que `alert_email` est vide.

locals {
  alertes_actives = var.alert_email != ""
}

resource "google_project_service" "monitoring" {
  service            = "monitoring.googleapis.com"
  disable_on_destroy = false
}

# À qui écrire.
resource "google_monitoring_notification_channel" "email" {
  count = local.alertes_actives ? 1 : 0

  display_name = "Alertes ${var.domain}"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }

  depends_on = [google_project_service.monitoring]
}

# La visite : /healthz en HTTPS, toutes les 5 minutes. Cette page ne répond 200 que
# si la base répond aussi. Un certificat expiré compte comme un échec.
resource "google_monitoring_uptime_check_config" "site" {
  count = local.alertes_actives ? 1 : 0

  display_name = "${var.domain} /healthz"
  timeout      = "10s"
  period       = "300s"

  http_check {
    path         = "/healthz"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.domain
    }
  }

  depends_on = [google_project_service.monitoring]
}

# L'alerte : la visite échoue depuis au moins deux régions. Une seule région en
# échec, c'est souvent le réseau de cette région, pas le site.
resource "google_monitoring_alert_policy" "site_injoignable" {
  count = local.alertes_actives ? 1 : 0

  display_name = "${var.domain} ne répond plus"
  combiner     = "OR"

  conditions {
    display_name = "La visite de /healthz échoue depuis au moins deux régions"

    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\" AND metric.label.check_id=\"${google_monitoring_uptime_check_config.site[0].uptime_check_id}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "300s"

      aggregations {
        alignment_period     = "1200s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.host"]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email[0].name]

  documentation {
    content   = "Le site ne répond plus depuis l'extérieur. Vérifier d'abord si la machine est en marche (console Google Cloud, Compute Engine), puis l'état des conteneurs sur le serveur."
    mime_type = "text/markdown"
  }
}
