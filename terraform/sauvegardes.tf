# Les sauvegardes : un espace de stockage hors du serveur.
#
# Une sauvegarde rangée sur le disque du serveur disparaît avec lui. Celle-ci part
# chaque nuit dans un « bucket » : si la machine est perdue, effacée ou compromise,
# les copies restent.

resource "google_project_service" "storage" {
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

resource "google_storage_bucket" "sauvegardes" {
  # Le nom d'un bucket est unique au monde : on le fait commencer par l'identifiant
  # du projet, qui l'est déjà.
  name     = "${var.project_id}-sauvegardes"
  location = var.region

  # Jamais public, quoi qu'on règle ensuite objet par objet.
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true

  # Le bucket ne se détruit pas tant qu'il contient des sauvegardes.
  force_destroy = false

  # Chaque sauvegarde est supprimée toute seule passé ce délai : on ne garde pas
  # des données personnelles plus longtemps que nécessaire, et la facture reste plate.
  lifecycle_rule {
    condition {
      age = var.backup_retention_days
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.storage]
}

# Le seul droit du serveur dans tout le projet : DÉPOSER un fichier dans ce bucket.
# Il ne peut ni lire, ni remplacer, ni supprimer une sauvegarde. Un serveur
# compromis ne peut donc pas effacer les copies qui permettraient de le réparer.
resource "google_storage_bucket_iam_member" "serveur_depose" {
  bucket = google_storage_bucket.sauvegardes.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.vm.email}"
}
