#!/bin/bash
# Desktop: niri + Dux Shell, login con greetd + dms-greeter. Solo l'essenziale.
source "$(dirname "$0")/vars.sh"

dnf5 -y copr enable "${DMS_COPR}"
dnf5 -y copr enable "${DMS_DEPS_COPR}"

# Senza dipendenze deboli: evita cava, waybar, fuzzel, alacritty, swaylock...
dnf5 -y install --setopt=install_weak_deps=False \
    niri xwayland-satellite xdg-desktop-portal-gnome xdg-desktop-portal-gtk gnome-keyring \
    dms dms-greeter quickshell matugen danksearch \
    greetd \
    foot Thunar \
    brightnessctl wl-clipboard \
    rsms-inter-fonts material-symbols-fonts google-noto-emoji-fonts

dnf5 -y copr disable "${DMS_COPR}"
dnf5 -y copr disable "${DMS_DEPS_COPR}"

# Dux Shell parte con la sessione grafica per ogni nuovo utente
install -d /etc/skel/.config/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/dms.service     /etc/skel/.config/systemd/user/graphical-session.target.wants/dms.service

systemctl enable greetd.service
# Il target (grafico o no) lo sceglie mbp-modo-generator a ogni avvio
