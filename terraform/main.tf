# Le serveur KalmQA : une seule machine, son réseau, son pare-feu, son adresse.
#
# Tout ce qui existe dans le cloud pour ce projet est décrit ici. Rien n'est
# créé à la main dans la console : ce qu'on ne lit pas dans ce fichier n'existe pas.

# Les services Google nécessaires. Les laisser activés à la destruction évite de
# casser un autre usage du projet.
resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iap" {
  service            = "iap.googleapis.com"
  disable_on_destroy = false
}

# ─── Réseau ───────────────────────────────────────────────────────────────────

# Un réseau à part, plutôt que le réseau « default » ouvert de Google : on sait
# exactement ce qui y entre.
resource "google_compute_network" "main" {
  name                    = var.name_prefix
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "main" {
  name          = var.name_prefix
  network       = google_compute_network.main.id
  region        = var.region
  ip_cidr_range = "10.10.0.0/24"
}

# ─── Pare-feu : deux portes, pas une de plus ──────────────────────────────────

# Le web, pour tout le monde. Seul le proxy écoute sur ces ports.
resource "google_compute_firewall" "web" {
  name      = "${var.name_prefix}-web"
  network   = google_compute_network.main.id
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.name_prefix}-web"]
}

# SSH, mais pas depuis Internet : uniquement depuis le tunnel de Google (IAP),
# qui vérifie d'abord l'identité de la personne. Le port 22 n'est donc jamais
# exposé aux robots qui balaient le réseau.
resource "google_compute_firewall" "ssh_iap" {
  name      = "${var.name_prefix}-ssh-iap"
  network   = google_compute_network.main.id
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Plage d'adresses du service IAP de Google.
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["${var.name_prefix}-ssh"]
}

# ─── Adresse ──────────────────────────────────────────────────────────────────

# Une adresse fixe : l'enregistrement DNS pointe dessus et ne change pas si la
# machine est recréée.
# « signsen » est le premier nom de l'application, aujourd'hui Ytosign. Il reste dans
# le nom de l'adresse et de la machine : le changer les ferait détruire et recréer.
resource "google_compute_address" "signsen" {
  name   = "${var.name_prefix}-signsen"
  region = var.region

  depends_on = [google_project_service.compute]
}

# ─── Machine ──────────────────────────────────────────────────────────────────

# L'identité de la machine. Elle n'a AUCUN rôle : si le serveur est compromis,
# il ne peut rien faire dans le projet Google Cloud.
resource "google_service_account" "vm" {
  account_id   = "${var.name_prefix}-vm"
  display_name = "Serveur SignSen (aucun droit)"
}

resource "google_compute_instance" "signsen" {
  name         = "${var.name_prefix}-signsen"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["${var.name_prefix}-web", "${var.name_prefix}-ssh"]

  boot_disk {
    initialize_params {
      # Famille Debian 12 : Google fournit la dernière image corrigée à la création.
      image = "debian-cloud/debian-12"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.main.id

    access_config {
      nat_ip = google_compute_address.signsen.address
    }
  }

  metadata = {
    # Les accès SSH passent par les comptes Google (IAM), pas par des clés
    # déposées sur la machine.
    enable-oslogin = "TRUE"
  }

  # Installe Docker au premier démarrage. Rejouable : ne refait rien ensuite.
  # Le script prépare /opt/kalmqa ; on y reporte le préfixe choisi. Attention :
  # modifier ce script recrée la machine.
  metadata_startup_script = replace(file("${path.module}/startup.sh"), "/opt/kalmqa", "/opt/${var.name_prefix}")

  service_account {
    email  = google_service_account.vm.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  # Changer de taille demande d'arrêter la machine : on l'autorise explicitement.
  allow_stopping_for_update = true
}
