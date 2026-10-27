#!/usr/bin/env bash
# Préparation d'un VPS OVH (Ubuntu 24.04) pour la préproduction. À lancer UNE fois, en administrateur :
#   curl -fsSL https://raw.githubusercontent.com/fbaret/demo/main/outils/preparer-vps.sh -o preparer-vps.sh
#   less preparer-vps.sh        # relire avant d'exécuter
#   sudo bash preparer-vps.sh
# Ce que fait le script :
#   - mises à jour de sécurité automatiques, pare-feu (SSH, HTTP, HTTPS uniquement), protection fail2ban ;
#   - Docker et Docker Compose (paquets Ubuntu) ;
#   - un compte « deploiement » réservé aux mises en ligne automatiques depuis GitHub, avec sa propre clé SSH ;
#   - le dossier /srv/producteurs qui recevra le site.
# Il n'installe pas le site : c'est le déploiement automatique qui s'en charge ensuite.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Lancez ce script avec sudo."; exit 1; }
export DEBIAN_FRONTEND=noninteractive

echo "== Mises à jour du système"
apt-get update -q
apt-get upgrade -y -q
apt-get install -y -q ca-certificates curl ufw fail2ban unattended-upgrades docker.io docker-compose-v2
dpkg-reconfigure -f noninteractive unattended-upgrades
systemctl enable --now docker fail2ban

echo "== Pare-feu : SSH, HTTP et HTTPS uniquement"
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "== Compte de déploiement"
id deploiement >/dev/null 2>&1 || useradd --create-home --shell /bin/bash deploiement
usermod -aG docker deploiement
install -d -m 700 -o deploiement -g deploiement /home/deploiement/.ssh
if [ ! -f /home/deploiement/.ssh/cle_github ]; then
  sudo -u deploiement ssh-keygen -q -t ed25519 -N "" -C "github-actions-deploiement" -f /home/deploiement/.ssh/cle_github
  cat /home/deploiement/.ssh/cle_github.pub >> /home/deploiement/.ssh/authorized_keys
fi
chown deploiement:deploiement /home/deploiement/.ssh/authorized_keys
chmod 600 /home/deploiement/.ssh/authorized_keys

echo "== Dossier du site"
install -d -m 750 -o deploiement -g deploiement /srv/producteurs

IP=$(curl -fsS -4 https://ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
cat <<FIN

==============================================================================
Serveur prêt.

1. Adresse IP de ce serveur : $IP
   (à indiquer dans la zone DNS du domaine, enregistrement de type A)

2. Clé privée de déploiement, à copier dans GitHub :
   dépôt prodelien → Settings → Secrets and variables → Actions → New repository secret
   Nom : VPS_CLE_SSH      Valeur : tout le bloc ci-dessous, lignes BEGIN et END comprises

FIN
cat /home/deploiement/.ssh/cle_github
cat <<FIN

   Puis supprimez-la de ce serveur une fois copiée :
   sudo rm /home/deploiement/.ssh/cle_github

3. Variable GitHub à créer (onglet Variables) : VPS_HOTE = $IP
==============================================================================
FIN
