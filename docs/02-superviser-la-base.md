# Fiche 02 — Superviser la base

> Brouillon de fiche d'épisode. Démonstration rejouée le 12/11/2026 : base vue hors ligne en 9 s,
> alerte « firing » à 70 s, mesures rétablies 12 s après la relance.

## L'idée en une phrase

La fiche 01 disait *si* Ytosign répond ; ici on regarde **dans** la base — sans jamais donner ses clés à l'outil de supervision.

## Ce qu'on montre

1. Un exportateur qui traduit les statistiques de Postgres en mesures pour Prometheus.
2. Un compte `monitoring` qui lit les statistiques mais pas les données.
3. Le tableau de bord « Ytosign — base de données » : état, connexions utilisées, taille, transactions, lignes par table.
4. Deux alertes qui racontent la même panne sous deux angles.

## Démonstration 1 — le moindre privilège

```bash
docker exec deploy_db_1 psql -U monitoring -d signsen -h 127.0.0.1 -c "select count(*) from users"
# ERROR:  permission denied for table users
```

(`signsen` est le nom de la base : le premier nom de l'application, conservé pour ne pas déplacer les données.)

Le compte de supervision voit que la table `users` contient une ligne (c'est une statistique), mais il ne peut pas la lire. Si l'exportateur est compromis, les données ne le sont pas.

## Démonstration 2 — la base raconte ce que fait l'application

Ouvre le tableau de bord, puis inscris un compte dans Ytosign (http://localhost:3000/signup) : dans « Lignes par table », `users` et `sessions` montent d'un cran, avec quelques secondes de retard. C'est une estimation tenue par Postgres, pas un comptage exact.

## Démonstration 3 — une panne, deux alertes

```bash
cd deploy
docker compose -f compose.local.yaml stop db
```

- Le panneau « Postgres » passe à **Hors ligne** en moins de 15 s ; les autres panneaux se vident.
- Dans Prometheus, deux alertes se déclenchent autour d'une minute : `PostgresInjoignable` (la cause) et `YtosignInjoignable` (la conséquence pour l'utilisateur).
- La leçon : **une alerte sur le symptôme réveille, une alerte sur la cause oriente.** Sans la seconde, on chercherait d'abord du côté de l'application.

```bash
docker compose -f compose.local.yaml start db    # tout se referme en moins de 30 s
```

## Les notions

- **Exportateur** : un petit programme qui parle la langue d'un outil (ici Postgres) et la traduit pour Prometheus. Il en existe pour presque tout.
- **Moindre privilège** : chaque composant reçoit le strict nécessaire. Ici le rôle `pg_monitor`, rien de plus.
- **Symptôme et cause** : la sonde de la fiche 01 voit le symptôme, l'exportateur voit la cause.
- **`pg_up` et `up`** : `pg_up = 0`, l'exportateur répond mais la base non ; `up = 0`, c'est l'exportateur lui-même qui est tombé — et on ne sait plus rien, ce qui mérite aussi une alerte.

## Limites assumées, et la suite

- Les requêtes lentes ne sont pas suivies (il faudrait l'extension `pg_stat_statements`).
- Les sauvegardes ne sont ni faites ni surveillées : c'est un lot à part.
- Les alertes ne préviennent toujours personne (pas d'Alertmanager).
