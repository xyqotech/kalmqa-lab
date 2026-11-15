# Fiche 01 — La supervision en local

> Brouillon de fiche d'épisode. Démonstration rejouée le 12/11/2026 : sonde en échec après 12 s,
> alerte « pending » à 18 s, « firing » à 79 s, refermée 6 s après la relance.

## L'idée en une phrase

Avant de déployer quoi que ce soit, on apprend à **voir** si l'application répond — sur son propre poste, sans compte cloud.

## Ce qu'on montre

1. Une application qui tourne (Ytosign) avec sa base Postgres, et trois briques autour : sonde, Prometheus, Grafana.
2. Le tableau de bord « Ytosign — disponibilité » : état, disponibilité sur 24 h, code HTTP, temps de réponse.
3. Une panne provoquée, et ce qu'elle donne à l'écran.

## La démonstration

```bash
cd deploy
docker compose -f compose.local.yaml stop ytosign     # on coupe l'application
```

- Dans Grafana, « État » passe à **Hors ligne** en moins de 30 secondes.
- Dans Prometheus (onglet Alerts), `YtosignInjoignable` passe en **pending**, puis **firing** après 1 minute.

```bash
docker compose -f compose.local.yaml start ytosign    # on la relance
```

- L'état revient à **En ligne**, l'alerte se referme, et la panne reste visible : un trou dans les courbes, et une disponibilité sur 24 h qui a baissé.
- À remarquer : la première visite après la relance est lente (~300 ms contre ~20 ms ensuite). C'est le démarrage à froid.
- Pendant la panne, « Temps de réponse » est vide, pas vert : un échec rapide n'est pas une bonne nouvelle.

## Deuxième panne : la base

```bash
docker compose -f compose.local.yaml stop db          # on coupe Postgres, pas l'application
```

- La page de connexion s'affiche toujours (`/login` répond 200) : à l'œil, tout va bien.
- Le point de santé `/healthz`, lui, répond 503 : la sonde passe en échec en 16 s, l'alerte se déclenche à 80 s.
- La leçon : **on ne surveille pas une page, on surveille ce dont l'utilisateur a besoin.** Une sonde sur `/login` aurait raté cette panne.

```bash
docker compose -f compose.local.yaml start db         # sonde rétablie en 9 s, données intactes
```

## Les notions

- **Sonde boîte noire** : on teste de l'extérieur, comme un utilisateur, sans rien savoir du code. C'est le cousin du test de fumée.
- **Collecte par interrogation** : Prometheus va chercher les mesures, ce n'est pas l'application qui les pousse.
- **`for: 1m`** : une alerte attend avant de crier, pour ne pas réveiller quelqu'un sur un raté isolé.
- **Tout en fichiers** : le tableau de bord est dans le dépôt, donc relu, versionné, rejouable.

## Limite assumée, et la suite

La sonde dit *si* l'application répond, pas *ce qui se passe dedans*. Pour ça il faudra que Ytosign expose ses propres mesures (`/metrics`), et que la base soit supervisée elle aussi (connexions, taille, requêtes lentes) : ce sont des lots à part.
