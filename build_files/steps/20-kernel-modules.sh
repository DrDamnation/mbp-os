#!/bin/bash
# Unico step che tocca kernel e moduli: Wi-Fi BCM4331 col driver proprietario wl, precompilato.
source "$(dirname "$0")/vars.sh"

KVER=$(ls /usr/lib/modules | head -1)
dnf5 install -y \
    /tmp/akmods-rpms/common/broadcom-wl-*.rpm \
    /tmp/akmods-rpms/kmods/kmod-wl-"${KVER}"-*.rpm

# Il modulo deve esistere per il kernel dell'immagine, altrimenti build rossa
modinfo -k "$KVER" wl >/dev/null
