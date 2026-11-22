output "adresse_ip" {
  description = "Adresse publique du serveur."
  value       = google_compute_address.signsen.address
}

output "enregistrement_dns" {
  description = "L'enregistrement à créer chez le gestionnaire du domaine (Cloudflare : nuage gris, « DNS only »)."
  value       = "${var.domain}  A  ${google_compute_address.signsen.address}"
}

output "connexion_ssh" {
  description = "Ouvre une session sur le serveur, par le tunnel IAP."
  value       = "gcloud compute ssh ${google_compute_instance.signsen.name} --project ${var.project_id} --zone ${var.zone} --tunnel-through-iap"
}

output "tunnel_supervision" {
  description = "Rend Grafana (3001) et Prometheus (9090) du serveur accessibles sur ton poste, le temps de la session."
  value       = "gcloud compute ssh ${google_compute_instance.signsen.name} --project ${var.project_id} --zone ${var.zone} --tunnel-through-iap -- -N -L 3001:127.0.0.1:3001 -L 9090:127.0.0.1:9090"
}

output "bucket_sauvegardes" {
  description = "Le bucket où le serveur dépose ses sauvegardes. À reporter dans le .env du serveur (BACKUP_BUCKET)."
  value       = google_storage_bucket.sauvegardes.name
}
