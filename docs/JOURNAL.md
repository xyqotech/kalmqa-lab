# Journal de bord KalmQA

> Dernière mise à jour : 23 novembre 2026.
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
| Mise en production, DNS, e-mails réels | Fait ; serveur en service continu depuis le 22/11 | `https://ytosign.com` |
| Parcours de signature complet en production | Validé, y compris sur iPhone | — |
| Renommage en Ytosign : application, dépôt, image | Fait, fusionné | Ytosign, commit `2ac5991` |
| Renommage en Ytosign : ce dépôt | Fait, validé sur la pile locale | `deploy/`, `monitoring/` |
| Renommage en Ytosign : DNS et déploiement | Fait le 15/11, vérifié | `https://ytosign.com` |
| Sauvegarde quotidienne hors du serveur | Fait le 22/11, restauration essayée ; première nuit automatique réussie le 23/11 | `deploy/sauvegarde/`, `terraform/sauvegardes.tf` |
| Envoi des alertes par e-mail | Fait le 22/11 ; chaîne validée en local, e-mails d'essai reçus en production | `monitoring/alertmanager/`, `monitoring/prometheus/rules*/` |
| Vérification du site depuis l'extérieur | Fait le 22/11, appliqué | `terraform/alertes.tf` |
| Première application branchée sur l'API | Vérifié le 23/11 en production, parcours nominal : un document de 3 pages envoyé, signé par deux personnes et scellé ; 8 notifications envoyées, 8 acceptées au premier essai | — |
| Déploiement automatique | **À faire** | — |
| Tests sur Firefox et Safari | **À faire** | Ytosign |

Versions en service : Ytosign `sha-da8252c` (branche `main`, déployée le 16 novembre 2026), Postgres 18.6, Caddy 2.11.9, Prometheus 3.16.0, Alertmanager 0.35.0, node-exporter 1.13.1, Grafana 13.3.1.

## Ce qui tourne

**Sur le poste de travail** : la pile locale (`deploy/compose.local.yaml`), Ytosign sur
http://localhost:3000, Grafana sur http://localhost:3001, Prometheus sur http://localhost:9090,
Alertmanager sur http://localhost:9093.

**En production** : `https://ytosign.com`. **Depuis le 22 novembre 2026, le serveur tourne en
continu** : il n'est plus arrêté entre deux séances. Si le site ne répond pas, c'est une panne. Ne
l'arrêter qu'à la demande du mainteneur. L'adresse d'origine, `https://signsen.xyqo.ai`, redirige
vers la nouvelle, chemin compris.

Le serveur : une machine `e2-small` (2 Go) chez Google Cloud, en Belgique. Seuls les
ports 80 et 443 répondent depuis Internet. Les e-mails partent par Resend depuis `no-reply@xyqo.ai`. La pile vit dans `/opt/kalmqa` sur le serveur ; ses
réglages (`/opt/kalmqa/deploy/.env`) ont été générés sur le serveur et n'en sortent pas.

Ce serveur a été créé avant le choix du nom : ses ressources cloud et sa pile Docker gardent leur
préfixe d'origine. Deux réglages privés le fixent : `name_prefix` dans `terraform/terraform.tfvars`
(sur le poste) et `COMPOSE_PROJECT_NAME` dans le `.env` du serveur. Sur ce serveur, `/opt/kalmqa`
est un lien vers le dossier d'origine. Ne jamais y changer ces réglages ni passer `-p` à
`docker compose` : les données sont rangées sous le nom d'origine.

**Ce qui veille sur lui**, depuis le 22 novembre 2026 :

- une **sauvegarde** part chaque nuit, vers 2 h 30 (heure universelle), dans un bucket Google en
  Belgique : la base et le volume des documents. Elle y reste 30 jours. Le serveur peut y déposer,
  pas y relire ni y supprimer ;
- **Alertmanager** envoie un e-mail quand une alerte de Prometheus se déclenche (site ou base
  injoignables, disque ou mémoire presque pleins, sauvegarde en retard), et un second quand elle
  se referme ;
- **Google visite le site de l'extérieur** toutes les 5 minutes et écrit si la visite échoue : la
  supervision du serveur ne peut pas prévenir de sa propre panne.

**Garde-fou de facturation** : une alerte de budget mensuelle de 10 € existe sur le compte de
facturation depuis le 13 novembre 2026, avec un e-mail à 50, 90 et 100 %. Elle prévient, elle ne
coupe rien, et les coûts s'affichent avec un délai pouvant atteindre 24 heures. Le serveur en
continu coûte davantage que ce montant : le seuil est à relever.

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

Quatre précautions, apprises en déployant :

- un fichier supprimé ou renommé dans le dépôt reste sur le serveur après le dépôt : le retirer à
  la main (règles d'alerte, tableaux de bord) ;
- un service renommé dans le fichier compose laisse son ancien conteneur en marche : l'arrêter et
  le retirer avant `up -d`. Les volumes ne sont pas touchés ;
- Prometheus et Grafana ne relisent leurs fichiers qu'au redémarrage ;
- lancer `docker compose` **toujours depuis `/opt/kalmqa/deploy`**. Lancé depuis un autre chemin
  qui mène au même dossier, compose croit les fichiers montés déplacés et recrée leurs conteneurs,
  base et proxy compris : le site est coupé quelques secondes (22 novembre 2026).

Sauvegarder et restaurer :

- lancer une sauvegarde à la main : `sudo systemctl start kalmqa-sauvegarde.service`, puis lire
  `sudo journalctl -u kalmqa-sauvegarde.service -n 30` ;
- voir les sauvegardes : `gcloud storage ls -l gs://<bucket>/`, depuis le poste. Le nom du bucket
  est donné par `terraform output bucket_sauvegardes` ;
- essayer une restauration sans rien risquer : `sudo deploy/sauvegarde/essai-de-restauration
  <archive>` restaure dans une base jetable et compare le nombre de lignes de chaque table ;
- restaurer pour de bon, sur un serveur neuf : télécharger l'archive depuis le poste et la copier
  sur le serveur ; arrêter l'application ; `pg_restore --clean --if-exists` de `base.dump` dans la
  base ; extraire `documents.tar` dans le volume des documents ; relancer. À répéter une fois à
  blanc avant d'en avoir besoin.

Alertes : l'adresse prévenue est le réglage `ALERT_EMAIL_TO` du serveur, et `alert_email` dans
`terraform.tfvars` pour la visite de Google. Alertmanager se consulte par un tunnel SSH, port 9093.

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
- **Serveur en continu** depuis le 22 novembre 2026 : l'application sert à signer de vrais
  documents, depuis une autre application qui l'appelle par son API.
- **Sauvegardes** : une par nuit, hors du serveur, gardées 30 jours. Le serveur n'a qu'un droit
  dans le projet cloud, déposer : compromis, il ne peut pas effacer ses sauvegardes.
- **Alertes** : par e-mail, par le serveur SMTP de l'application. Alertmanager fabrique sa
  configuration au démarrage à partir des réglages existants : la clé d'envoi n'est écrite qu'à un
  endroit.
- **Deux regards** : la supervision du serveur pour ce qui se passe dedans, une visite extérieure
  pour le cas où il tombe entièrement.

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
16. **Le même dossier, deux chemins** : une commande lancée depuis un lien vers le dossier habituel.
    Compose a cru les fichiers déplacés et a recréé la base et le proxy. Quelques secondes de coupure.
17. **Le script qui avale la suite** : une commande lancée dans un conteneur lit l'entrée du script
    qui l'appelle ; le reste du script disparaît sans erreur. Lui fermer l'entrée.

## Prochains lots proposés

1. **Tests sur Firefox et Safari** dans Ytosign, puis dans sa CI.
2. **Déploiement automatique** : la mise à jour du serveur déclenchée depuis GitHub.
3. **Journal d'accès** du proxy.
4. **Analyse de sécurité** de l'image et des dépendances dans la CI.
5. **Une fiche** sur les sauvegardes et les alertes, et une restauration complète à blanc.
