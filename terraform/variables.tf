variable "project_id" {
  description = "Identifiant du projet Google Cloud qui héberge le serveur (un projet dédié, pour isoler les coûts)."
  type        = string
}

variable "region" {
  description = "Région Google Cloud."
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "Zone, dans la région choisie."
  type        = string
  default     = "europe-west1-b"
}

variable "machine_type" {
  description = "Taille de la machine. e2-small = 2 Go de mémoire : la pile complète en demande un peu plus de 1."
  type        = string
  default     = "e2-small"
}

variable "domain" {
  description = "Nom de domaine de l'instance Ytosign. Sert seulement à rappeler l'enregistrement DNS à créer."
  type        = string
  default     = "ytosign.com"
}

variable "name_prefix" {
  description = "Préfixe du nom de chaque ressource (réseau, pare-feu, adresse, machine) et du dossier de la pile sur le serveur. À fixer une fois : le changer ensuite recrée tout."
  type        = string
  default     = "kalmqa"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.name_prefix))
    error_message = "Le préfixe compte 3 à 21 caractères : minuscules, chiffres et tirets, en commençant par une lettre."
  }
}

variable "backup_retention_days" {
  description = "Nombre de jours pendant lesquels une sauvegarde est gardée dans le bucket, avant d'être supprimée toute seule."
  type        = number
  default     = 30

  validation {
    condition     = var.backup_retention_days >= 7
    error_message = "Garde au moins 7 jours de sauvegardes : une erreur ne se remarque pas toujours le lendemain."
  }
}

variable "alert_email" {
  description = "Adresse qui reçoit l'e-mail de Google quand le site ne répond plus. Vide : aucune vérification externe n'est créée. À renseigner dans terraform.tfvars, jamais ici."
  type        = string
  default     = ""
}
