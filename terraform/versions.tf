# Versions épinglées, comme partout dans ce dépôt : une montée de version du
# fournisseur est un commit qu'on relit (le fichier .terraform.lock.hcl la fige).
terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.11"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
