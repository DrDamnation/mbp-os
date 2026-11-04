#!/bin/bash
# MacBook Pro 10,2: ventole, niente sospensione (è anche un server), coperchio ignorato.
source "$(dirname "$0")/vars.sh"

dnf5 install -y lm_sensors
if dnf5 -q info mbpfan >/dev/null 2>&1; then
    dnf5 install -y mbpfan
else
    dnf5 install -y gcc make
    src=$(mktemp -d)
    curl -fsSL -o "$src/m.tgz" "https://github.com/linux-on-mac/mbpfan/archive/refs/tags/v${MBPFAN_VERSION}.tar.gz"
    echo "${MBPFAN_SHA256}  $src/m.tgz" | sha256sum -c -
    tar -xzf "$src/m.tgz" -C "$src"
    make -C "$src/mbpfan-${MBPFAN_VERSION}"
    install -Dm755 "$src/mbpfan-${MBPFAN_VERSION}/bin/mbpfan" /usr/sbin/mbpfan
    install -Dm644 "$src/mbpfan-${MBPFAN_VERSION}/mbpfan.service" /usr/lib/systemd/system/mbpfan.service
    rm -rf "$src"
    dnf5 remove -y gcc make
fi
systemctl enable mbpfan.service

# Mai in sospensione: né dal coperchio né dal desktop
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
