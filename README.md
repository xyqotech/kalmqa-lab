# kalmqa-lab

Le laboratoire de **KalmQA** : déployer et superviser une vraie application, de bout en bout,
étape par étape. L'application sous test est [Ytosign](https://ytosign.com), un service de
signature électronique. Ce dépôt ne contient **que l'infrastructure** : le code de l'application
vit dans son propre dépôt, comme en entreprise, et on en utilise l'image publiée.

Où en est le projet et ce qui a été décidé : [docs/JOURNAL.md](docs/JOURNAL.md).

## Contenu

| Dossier | Rôle | État |
|---|---|---|
| `deploy/` | Fichiers compose : la pile locale, et la pile de production | Écrits et validés |
| `monitoring/` | Configuration Prometheus, sonde, tableaux de bord Grafana, alertes | Écrit et validé |
| `terraform/` | Le serveur cloud, son réseau, son pare-feu, son adresse | Appliqué : le serveur existe |
| `.github/workflows/` | Plan Terraform et déploiement automatique | À venir |
| `docs/` | Une fiche par épisode | Fiches 01 à 03 |

## Lot 1 — la supervision en local

Ytosign, sa base, et trois briques de supervision :

- **Postgres** garde les enregistrements de Ytosign (comptes, demandes, journal de preuves) ;
- **la sonde** (blackbox exporter) interroge le point de santé `/healthz` de Ytosign, qui ne
  répond 200 que si la base répond aussi ;
- **l'exportateur Postgres** lit les statistiques de la base avec un compte `monitoring` qui ne
  peut pas lire les données ;
- **Prometheus** interroge la sonde et l'exportateur toutes les 15 secondes et garde l'historique ;
- **Grafana** affiche deux tableaux de bord : la disponibilité de Ytosign, et sa base
  (connexions, taille, transactions, lignes par table).

### Prérequis

- Docker avec **au moins 4 Go de mémoire** alloués (Docker Desktop → Settings → Resources). Si
  d'autres conteneurs tournent déjà, arrête-les ou augmente la mémoire avant de lancer.
- Rien d'autre : l'image de Ytosign est tirée toute seule, pour `linux/amd64` comme pour
  `linux/arm64`.

### Lancer

```bash
cd deploy
cp .env.example .env        # puis renseigne les trois mots de passe demandés
docker compose -f compose.local.yaml up -d
```

| Service | Adresse |
|---|---|
| Ytosign | http://localhost:3000 |
| Grafana (dossier KalmQA : « Ytosign — disponibilité » et « Ytosign — base de données ») | http://localhost:3001 |
| Prometheus (cibles : Status → Targets ; alertes : Alerts) | http://localhost:9090 |

Le compte `monitoring` est créé par `deploy/postgres/init/` au premier démarrage de la base.
Sur une base déjà initialisée, lance le script une fois à la main :

```bash
docker exec deploy_db_1 sh /docker-entrypoint-initdb.d/10-monitoring-role.sh
```

### Arrêter

```bash
cd deploy
docker compose -f compose.local.yaml down       # ajoute -v pour effacer aussi les données
```

## La pile de production

`deploy/compose.prod.yaml` fait tourner Ytosign **tel qu'il est publié** par sa CI
(`ghcr.io/xyqotech/ytosign`, étiquette `sha-…` épinglée dans le fichier), derrière un proxy HTTPS.
Seul le proxy est exposé ; Grafana et Prometheus ne sont joignables que depuis le serveur
lui-même, par un tunnel SSH, et Grafana exige une connexion.

Sur le serveur :

```bash
cd deploy
cp .env.prod.example .env      # nom de domaine, trois mots de passe, serveur SMTP
docker compose -f compose.prod.yaml up -d
```

Déployer une nouvelle version de Ytosign, c'est changer son étiquette `sha-…` dans
`compose.prod.yaml`, dans un commit.

### Répéter sur son poste

```bash
cd deploy
cp .env.prod.example .env.prod      # SITE_ADDRESS=localhost, MAIL_TRANSPORT=file
docker compose -p kalmqa-prod --env-file .env.prod -f compose.prod.yaml up -d
curl -k https://localhost/healthz
```

Les ports 80, 443, 3001 et 9090 doivent être libres : arrête d'abord Grafana et Prometheus de
la pile locale (`docker compose -f compose.local.yaml stop grafana prometheus`).

L'image de Ytosign est publiée pour `linux/amd64` et `linux/arm64` : la même commande tire
la bonne variante sur un serveur comme sur un Mac à puce Apple.

## Règles du dépôt

- **Versions épinglées**, jamais `latest` : une montée de version est un commit qu'on relit.
- **Rien n'est cliqué à la main** : source de données, tableaux de bord et alertes sont des fichiers.
- **Aucun secret commité** : les valeurs sensibles vivent dans `.env`, ignoré par Git.

## Validé le 12/11/2026

L'application s'appelait alors SignSen et se construisait depuis ses sources : son service, ses
alertes et ses tableaux de bord ont été renommés depuis, la pile locale tire maintenant l'image
publiée. Les mesures restent celles de ce jour-là.

Sur Docker Desktop (8 Go, 8 CPU), Ytosign construit depuis sa branche `main` (commit `b57f682`) :

- la pile démarre : Ytosign, Postgres 18.6, sonde, Prometheus, Grafana ;
- Ytosign crée son schéma au démarrage (10 tables, déclencheurs du journal de preuves) et une
  inscription faite dans le navigateur arrive bien en base ;
- les cibles Prometheus sont « up », le tableau de bord se charge seul dans Grafana ;
- **panne de l'application** (`stop ytosign`) : sonde en échec après 12 s, alerte « firing » à 79 s ;
- **panne de la base** (`stop db`) : `/healthz` passe à 503 alors que `/login` reste à 200 ;
  sonde en échec après 16 s, alerte « pending » à 19 s, « firing » à 80 s ; à la relance,
  sonde rétablie en 9 s, alerte refermée en 12 s, données intactes.

- **supervision de la base** : le compte `monitoring` se voit refuser la lecture de `users` ;
  base arrêtée, `pg_up` passe à 0 en 9 s et `PostgresInjoignable` se déclenche à 70 s, en même
  temps que `YtosignInjoignable` ; tout se referme 28 s après la relance.

Mémoire mesurée : Grafana 400 à 550 Mo, Ytosign ~65 Mo, Prometheus ~50 Mo, Postgres ~30 Mo,
sonde ~25 Mo, exportateur ~8 Mo. À garder en tête pour le choix de la VM cloud.

**Pile de production**, répétée sur le même poste (Mac ARM) avec l'image publiée `sha-5480708` :

- le poste tire la variante `arm64` de l'image, et Ytosign répond 200 à travers le proxy
  HTTPS ; le HTTP simple est redirigé vers HTTPS ;
- les quatre cibles Prometheus sont « up » ; sur une base neuve, le compte `monitoring` se
  crée tout seul ;
- Grafana répond 401 sans connexion et sert les deux tableaux de bord à l'administrateur ;
- seul le proxy publie des ports ; les journaux des conteneurs sont plafonnés.

**En production**, sur le serveur Google Cloud créé par `terraform/` (`e2-small`, 2 Go) :

- https://signsen.xyqo.ai répond 200, avec un certificat Let's Encrypt obtenu tout seul par le
  proxy ; le HTTP simple est redirigé vers HTTPS ;
- le serveur a tiré la variante `amd64` de l'image publiée ;
- les quatre cibles Prometheus sont « up », la base a ses 10 tables et son compte `monitoring` ;
- depuis Internet, seuls les ports 80 et 443 répondent : SSH, Grafana, Prometheus et la base
  sont fermés ;
- mémoire utilisée : environ 900 Mo sur 2 Go, dont 420 pour Grafana.

- les e-mails partent pour de bon, par Resend, depuis `no-reply@xyqo.ai` ;
- **un parcours de signature complet** a été joué : une demande, deux signataires, codes reçus
  par e-mail, document scellé. Le PDF téléchargé a la même empreinte que celle enregistrée sur
  le serveur, les 16 événements du journal de preuves s'enchaînent sans rupture, et les
  adresses IP relevées sont celles des visiteurs, pas celles du proxy.

**Pas validé** : la sauvegarde et la restauration, l'envoi des alertes, et un redémarrage du
serveur.

Piège rencontré : quand on change l'URL d'une cible, l'ancienne série reste visible cinq
minutes dans Prometheus avec sa dernière valeur. Une alerte peut se déclencher sur ce fantôme.
