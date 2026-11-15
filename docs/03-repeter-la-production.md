# Fiche 03 — Répéter la production sur son poste

> Brouillon de fiche d'épisode. Répétition jouée le 12/11/2026 sur un Mac ARM, avec un incident
> réel en chemin (voir « L'incident »), corrigé le jour même dans la CI de Ytosign.

## L'idée en une phrase

Avant de louer un serveur, on fait tourner **le fichier de production lui-même** sur son poste : les surprises coûtent moins cher ici.

## Ce qui change entre « local » et « production »

| | `compose.local.yaml` | `compose.prod.yaml` |
|---|---|---|
| Ytosign | image publiée par sa CI, étiquette `sha-…` | la même image |
| Porte d'entrée | port 3000, en HTTP | proxy Caddy, ports 80 et 443, HTTPS |
| Grafana | lecture sans connexion | connexion obligatoire |
| Grafana, Prometheus | sur le poste | liés à 127.0.0.1 du serveur : tunnel SSH |
| E-mails | écrits sur le disque | vrai serveur SMTP |
| Journaux | sans limite | plafonnés (3 fichiers de 10 Mo) |

## La démonstration

```bash
cd deploy
cp .env.prod.example .env.prod      # SITE_ADDRESS=localhost, MAIL_TRANSPORT=file, trois mots de passe
docker compose -p kalmqa-prod --env-file .env.prod -f compose.prod.yaml up -d
curl -k https://localhost/healthz   # ok
```

- `http://localhost` renvoie vers `https://localhost` : le proxy impose le HTTPS.
- Le certificat vient d'une autorité locale fabriquée par Caddy, d'où le `-k` (et l'avertissement du navigateur). Avec un vrai nom de domaine, il viendrait de Let's Encrypt, sans rien changer au fichier.
- `docker ps` : seul le proxy publie des ports vers l'extérieur. Ytosign et la base n'en ont aucun.
- Grafana répond 401 sans mot de passe.

## L'incident

Premier lancement sur un Mac ARM : le proxy répond **502**. Les conteneurs sont « running », sauf Ytosign, « unhealthy ». Son journal :

```
v8::internal::V8::FatalProcessOutOfMemory
qemu: uncaught target signal 5 (Trace/breakpoint trap) - core dumped
```

- **Le symptôme trompe** : « out of memory », alors que la mémoire ne manque pas.
- **La cause** : l'image publiée est faite pour `linux/amd64` (le serveur visé). Sur un poste ARM, Docker l'exécute dans un émulateur, et celui des anciennes versions de Docker Desktop ne sait pas faire démarrer Node 22.
- **La preuve** : une image Node 22 officielle, nue, plante de la même façon en `amd64` sur ce poste. Ce n'est donc ni Ytosign ni son image — que la CI avait d'ailleurs démarrée avant de la publier.
- **La parade du moment** : une surcharge compose de trois lignes (`-f compose.prod.yaml -f surcharge.yaml`) qui remplaçait, pour la répétition seulement, l'image publiée par celle construite sur le poste. Elle faisait passer la répétition, mais ce n'était plus tout à fait la production qu'on répétait.
- **La vraie correction** : publier l'image pour les deux architectures. La CI de Ytosign la construit maintenant sur une machine `amd64` et une machine `arm64`, démarre chacune avant de la publier, puis réunit les deux sous la même étiquette. La surcharge a été supprimée : la même commande tire la bonne variante partout.
- **Pourquoi deux machines** : Ytosign embarque un binaire propre à chaque processeur (une bibliothèque d'images). On ne peut pas fabriquer l'image ARM depuis une machine Intel par simple recopie.
- **Le piège dans le piège** : tester avec `docker run --platform linux/amd64 node:22-…` remplace l'image Node en cache par sa variante `amd64`. Les constructions suivantes partent alors de la mauvaise architecture. Il faut la retirer : `docker pull --platform linux/arm64 node:22-bookworm-slim`.

## Les notions

- **Architecture d'une image** : une image est compilée pour un processeur. « Ça marche sur mon poste » peut vouloir dire « sur mon processeur ».
- **Fichiers compose superposés** : plusieurs `-f` se fusionnent, le dernier gagne. Pratique pour une exception qu'on veut visible et isolée — et qu'on supprime dès que la cause est corrigée.
- **Image multi-architecture** : une étiquette, plusieurs images ; Docker choisit celle de la machine.
- **Une seule porte** : n'exposer que le proxy réduit ce qu'un attaquant peut atteindre.
- **Étiquette immuable** : `sha-…` désigne toujours la même image ; `main` et `latest` non.

## Limites assumées, et la suite

- Sur ce poste, c'est la variante `arm64` qui a tourné. La variante `amd64`, celle du serveur, n'a tourné que dans la CI.
- Pas de sauvegarde, pas d'envoi d'alertes, pas de limite de mémoire par conteneur.
