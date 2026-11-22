# terraform/

Le serveur KalmQA sur Google Cloud : une machine, son réseau, son pare-feu, son adresse, et ce
qui veille sur elle (sauvegardes, visite extérieure).

| Ressource | Rôle |
|---|---|
| Réseau `kalmqa` | Un réseau à part, pas le réseau « default » ouvert de Google |
| Pare-feu `kalmqa-web` | Ports 80 et 443, pour tout le monde |
| Pare-feu `kalmqa-ssh-iap` | Port 22, uniquement depuis le tunnel IAP de Google |
| Adresse `kalmqa-signsen` | Adresse fixe, sur laquelle pointe le DNS |
| Compte de service `kalmqa-vm` | L'identité de la machine. Un seul droit : déposer dans le bucket des sauvegardes |
| Machine `kalmqa-signsen` | `e2-small` (2 Go), Debian 12, Docker installé au démarrage |
| Bucket `<projet>-sauvegardes` | Les sauvegardes, hors du serveur, supprimées après 30 jours. Jamais public |
| Visite `/healthz` et son alerte | Google visite le site toutes les 5 minutes et écrit à `alert_email` si la visite échoue. Créées seulement si `alert_email` est renseigné |

L'adresse et la machine portent le premier nom de l'application, « signsen » (aujourd'hui
Ytosign). Ce nom ne se change pas : Terraform détruirait le serveur pour en créer un autre.

## Avant de commencer

1. Un compte Google Cloud **complet** (facturation activée) et un **projet dédié**.
2. Se connecter, deux fois — une pour `gcloud`, une pour Terraform :

```bash
gcloud auth login
gcloud auth application-default login
```

## Créer le serveur

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars    # renseigne project_id
terraform init
terraform plan      # lis ce qui va être créé AVANT de l'accepter
terraform apply
```

`terraform apply` affiche à la fin l'adresse du serveur, l'enregistrement DNS à créer et les
commandes de connexion.

## Ensuite

- **DNS** : crée l'enregistrement `A` indiqué, chez le gestionnaire du domaine. Sur Cloudflare,
  laisse-le en « DNS only » (nuage gris) : le proxy du serveur obtient lui-même son certificat,
  et Ytosign doit voir l'adresse réelle des signataires.
- **Connexion** : `terraform output -raw connexion_ssh` donne la commande. Aucune clé SSH à
  gérer : l'accès passe par ton compte Google.
- **Supervision** : `terraform output -raw tunnel_supervision` ouvre Grafana et Prometheus du
  serveur sur ton poste.

## Détruire

```bash
terraform destroy
```

Tout ce que ce dossier a créé disparaît, et la facturation avec. Exception voulue : le bucket
refuse d'être détruit tant qu'il contient des sauvegardes. Les télécharger ou les supprimer d'abord.

## Ce qu'il faut savoir

- **Préfixe des noms** : la variable `name_prefix` (par défaut `kalmqa`) nomme chaque ressource et
  le dossier de la pile sur le serveur. Choisis-la avant le premier `apply` : la changer ensuite
  recrée le réseau, l'adresse et la machine.
- **Coût** : la machine, son disque et son adresse publique sont payants. Ordre de grandeur :
  15 à 20 € par mois, à vérifier dans le calculateur de Google avant de créer.
- **État Terraform** : il est gardé sur le poste (`terraform.tfstate`, ignoré par Git). Suffisant
  pour une personne seule ; en équipe, il irait dans un stockage partagé.
- **Appliqué le 12/11/2026** : 9 ressources créées, serveur en marche, pile déployée dessus.
  Complété le 22/11/2026 : bucket des sauvegardes, droit de dépôt, visite extérieure et son alerte.
- **Si la seconde connexion échoue** (`gcloud auth application-default login`), Terraform accepte
  un jeton temporaire de la ligne de commande :
  `GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)" terraform plan`
- **Réseau `default`** : Google en crée un tout seul dans chaque projet, avec SSH et RDP ouverts
  au monde. Le serveur n'est pas dessus, mais il vaut mieux le supprimer.
