#!/bin/bash
# Serverino: Docker + Compose, Tailscale, SSH solo con chiave, stack in modo server.
source "$(dirname "$0")/vars.sh"

dnf5 -y install --setopt=install_weak_deps=False moby-engine docker-compose git openssh-server

# Tailscale dal repo ufficiale, poi repo spento (l'immagine si aggiorna in blocco)
curl -fsSL -o /etc/yum.repos.d/tailscale.repo \
    "https://pkgs.tailscale.com/stable/fedora/tailscale.repo"
dnf5 -y install tailscale
sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/tailscale.repo

systemctl enable docker.service tailscaled.service sshd.service mbp-stacks.service
