#!/bin/bash
# Prépare le serveur : Docker, un peu de mémoire d'échange, le dossier de la pile.
# Exécuté par Google à chaque démarrage de la machine ; chaque étape vérifie
# d'abord si elle a déjà été faite.
set -euo pipefail

# Docker Engine et son greffon compose, depuis le dépôt officiel de Docker.
if ! command -v docker >/dev/null 2>&1; then
  apt-get update
  apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

# 1 Go d'échange : une marge si un conteneur déborde, plutôt qu'un arrêt brutal.
if [ ! -f /swapfile ]; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Là où la pile sera déposée.
install -d -m 0755 /opt/kalmqa
