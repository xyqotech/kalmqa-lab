# Journal de bord KalmQA

> Dernière mise à jour : 15 novembre 2026.
> Ce journal dit où en est le projet, ce qui a été décidé et comment l'exploiter.
> Il ne contient ni secret, ni adresse, ni identifiant de compte.

## Le projet en quelques lignes

**KalmQA** est une activité de formation gratuite, par la pratique, sur les réseaux sociaux :
que les informaticiens n'aient plus peur de l'automatisation des tests, du DevOps et du CI/CD.
Public : France et Europe d'abord. Sous-titre envisagé : « De la QA au déploiement, sans stress ».

Le fil conducteur est une vraie application, **Ytosign** (signature électronique), déployée et
supervisée de bout en bout. Ce dépôt, `kalmqa-lab`, contient l'infrastructure ; le code de
l'application reste dans le sien, qui est privé.

L'application s'appelait SignSen jusqu'au 15 novembre 2026. Quelques noms techniques gardent ce
premier nom, volontairement : voir « Décisions prises ».

## Où on en est

| Lot | État | Où |
|---|---|---|
| Pile locale : Ytosign + Postgres + supervision | Fait, validé | `deploy/compose.local.yaml`, fiche 01 |
| Supervision de la base (compte en lecture seule) | Fait, validé | `monitoring/`, fiche 02 |
| Ytosign sur Postgres (au lieu de SQLite) | Fait, fusionné | Ytosign, commit `c6476a8` |
| Image construite et publiée par la CI, deux architectures | Fait | Ytosign, `.github/workflows/ci.yml` |
| Pile de production derrière un proxy HTTPS | Fait, validé | `deploy/compose.prod.yaml`, fiche 03 |
| Serveur Google Cloud décrit avec Terraform | Fait, appliqué | `terraform/` |
| Mise en production, DNS, e-mails réels | Fait ; serveur arrêté entre deux séances | `https://ytosign.com` |
| Parcours de signature complet en production | Validé, y compris sur iPhone | — |
| Renommage en Ytosign : application, dépôt, image | Fait, fusionné | Ytosign, commit `2ac5991` |
| Renommage en Ytosign : ce dépôt | Fait, validé sur la pile locale | `deploy/`, `monitoring/` |
| Renommage en Ytosign : DNS et déploiement | Fait le 15/11, vérifié | `https://ytosign.com` |
| Déploiement automatique | **À faire** | — |
| Tests sur Firefox et Safari | **À faire** | Ytosign |

Versions en service : Ytosign `sha-da8252c` (branche `main`, déployée le 16 novembre 2026), Postgres 18.6, Caddy 2.11.9, Prometheus 3.16.0, Grafana 13.3.1.

## Ce qui tourne

**Sur le poste de travail** : la pile locale (`deploy/compose.local.yaml`), Ytosign sur
http://localhost:3000, Grafana sur http://localhost:3001, Prometheus sur http://localhost:9090.

**En production** : `https://ytosign.com`. **Entre deux séances, le serveur est arrêté
volontairement**, pour ne rien consommer : le site ne répond alors pas, ce n'est pas une panne.
Vérifier son état réel avant de conclure. L'adresse d'origine, `https://signsen.xyqo.ai`, redirige
vers la nouvelle, chemin compris. Les données sont intactes sur son disque ; le disque et
l'adresse réservée restent facturés. Ne le relancer qu'à la demande du mainteneur.

Quand il tourne : une machine `e2-small` (2 Go) chez Google Cloud, en Belgique. Seuls les
ports 80 et 443 répondent depuis Internet. Les e-mails partent par Resend depuis `no-reply@xyqo.ai`. La pile vit dans `/opt/kalmqa` sur le serveur ; ses
réglages (`/opt/kalmqa/deploy/.env`) ont été générés sur le serveur et n'en sortent pas.

Ce serveur a été créé avant le choix du nom : ses ressources cloud et sa pile Docker gardent leur
préfixe d'origine. Deux réglages privés le fixent : `name_prefix` dans `terraform/terraform.tfvars`
(sur le poste) et `COMPOSE_PROJECT_NAME` dans le `.env` du serveur. Sur ce serveur, `/opt/kalmqa`
est un lien vers le dossier d'origine. Ne jamais y changer ces réglages ni passer `-p` à
`docker compose` : les données sont rangées sous le nom d'origine.

**Garde-fou de facturation** : une alerte de budget mensuelle de 10 € existe sur le compte de
facturation depuis le 13 novembre 2026, avec un e-mail à 50, 90 et 100 %. Elle prévient, elle ne
coupe rien, et les coûts s'affichent avec un délai pouvant atteindre 24 heures.

## Comment faire

Se connecter au serveur, ouvrir la supervision : les commandes exactes sont données par
`terraform output` (dans `terraform/`).

Arrêter ou relancer le serveur : `gcloud compute instances stop` ou `start`, avec le nom de la
machine, la zone et le projet que donne `terraform output`. Après un démarrage, les conteneurs
repartent seuls (vérifié le 14 novembre 2026) : le contrôler sur la page `/healthz` du site.
Terraform ne modifie pas l'état marche/arrêt.

Redéployer une nouvelle version de Ytosign :

1. Attendre que la CI de Ytosign ait publié l'image (`sha-<commit>`).
2. Changer l'étiquette dans `deploy/compose.prod.yaml`, commiter, pousser.
3. Redéposer `deploy/` et `monitoring/` dans `/opt/kalmqa` sur le serveur (jamais les `.env`).
4. Sur le serveur : `sudo docker compose -f compose.prod.yaml pull ytosign`, puis `up -d`.
5. Vérifier la page `/healthz` du site, puis les données et la supervision.

Trois précautions, apprises au déploiement du renommage (15 novembre 2026) :

- un fichier supprimé ou renommé dans le dépôt reste sur le serveur après le dépôt : le retirer à
  la main (règles d'alerte, tableaux de bord) ;
- un service renommé dans le fichier compose laisse son ancien conteneur en marche : l'arrêter et
  le retirer avant `up -d`. Les volumes ne sont pas touchés ;
- Prometheus et Grafana ne relisent leurs fichiers qu'au redémarrage.

Changer la clé d'envoi d'e-mails : `sudo /opt/kalmqa/bin/brancher-resend` sur le serveur,
dans un vrai terminal. La clé se saisit sans s'afficher.

Si `gcloud auth application-default login` échoue, Terraform accepte un jeton temporaire :
`GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)" terraform plan`.

## Décisions prises

- **Nom du projet** : KalmQA. Sous-titre : « De la QA au déploiement, sans stress ».
- **Nom de l'application** : Ytosign, depuis le 15 novembre 2026. Elle s'appelait SignSen.
- **Code de l'application** : dans un dépôt à part, privé. Ce laboratoire n'en utilise que
  l'image publiée, la même en local et en production.
- **Ce qui garde le premier nom, volontairement** : la base et son rôle Postgres (`signsen`), les
  volumes `signsen-data` et `signsen-db`, le nom de la machine et de son adresse dans le cloud.
  Les renommer ferait démarrer la pile sur des données vides ou recréerait le serveur. Aucun
  visiteur ne voit ces noms.
- **Sceau du serveur** : renouvelé le 15 novembre 2026, parce que son certificat portait l'ancien
  nom et s'imprimait dans chaque certificat de preuve. L'ancien sceau est conservé sur le volume
  de données, dans un dossier à part. Les documents scellés avant gardent l'ancien certificat à
  l'intérieur, définitivement ; depuis la version `sha-018be7f`, l'application les reconnaît
  grâce à l'empreinte notée au journal d'audit lors du scellement.
- **Application de démonstration** : Ytosign. L'autre projet du mainteneur sert de source
  d'incidents vécus, en extraits seulement.
- **Cloud** : Google Cloud, machine à 2 Go (la machine gratuite à 1 Go est trop juste : Grafana
  prend à lui seul 400 à 550 Mo).
- **Base de Ytosign** : Postgres remplace SQLite, sans double support.
- **Domaine** : `ytosign.com`, en service depuis le 15 novembre 2026. L'adresse d'origine,
  `signsen.xyqo.ai`, reste en redirection (réglage `OLD_SITE_ADDRESS` du serveur) pour que les
  liens déjà envoyés par e-mail fonctionnent. Enregistrements en « DNS only » chez Cloudflare.
- **E-mails** : Resend, expéditeur `no-reply@xyqo.ai`, inchangé après le renommage.
- **Ytosign** : l'annulation d'une demande est refusée une fois que tout le monde a signé ;
  l'envoi est refusé tant que le titre est resté « Nouvelle demande ».
- **Infrastructure à part** : ce dépôt ne contient pas le code de l'application.

## Incidents vécus (matière d'épisodes)

Chacun est une histoire courte : le symptôme, la fausse piste, la cause, la parade.

1. **La mémoire de Docker** : 2 Go alloués, déjà occupés par une autre pile. Regarder avant de lancer.
2. **Un réglage qui ne s'enregistre pas** : curseur déplacé, bouton de validation oublié.
3. **Le temps de réponse vert pendant une panne** : un échec est rapide. Ne compter que les réussites.
4. **La série fantôme de Prometheus** : une cible renommée reste visible cinq minutes et déclenche une alerte.
5. **`/login` à 200, base arrêtée** : on surveille ce dont l'utilisateur a besoin, pas une page.
6. **L'image `amd64` sur un Mac ARM** : fausse erreur de mémoire, vraie limite de l'émulateur.
   Correction : une image pour les deux architectures.
7. **Le test qui casse le poste** : forcer une architecture remplace l'image de base en cache.
8. **`true` n'est pas du texte** : YAML lit un booléen, compose refuse le fichier.
9. **Le bouton oublié** : chaque section du formulaire avait le sien. Un PDF choisi n'était pas envoyé.
10. **Le PDF que l'iPhone refuse** : document déjà modifié, table interne décalée après réécriture.
    Chrome répare en silence, Apple refuse. Sceau valide, fichier illisible.
11. **La case non cochée** : une connexion Google réussie, mais sans la permission utile.
12. **Le réseau par défaut** : créé tout seul par le fournisseur, portes ouvertes au monde.
13. **Le lien dans la capture d'écran** : un lien de réinitialisation valide, partagé en entier.
14. **Les robots** : le site est sondé quelques heures après sa mise en ligne.
15. **Pas de trace** : le proxy n'enregistrait pas les requêtes, impossible de voir ce qu'a fait un visiteur.

## Prochains lots proposés

1. **Tests sur Firefox et Safari** dans Ytosign, puis dans sa CI.
2. **Déploiement automatique** : la mise à jour du serveur déclenchée depuis GitHub.
3. **Sauvegardes** de la base et des documents, avec un essai de restauration.
4. **Envoi des alertes** et journal d'accès du proxy.
5. **Analyse de sécurité** de l'image et des dépendances dans la CI.
