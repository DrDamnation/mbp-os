#!/usr/bin/env bash
# Esegue i %post del kickstart dentro l'immagine vera (senza bootc switch) e verifica
# che alla fine si possa entrare: daniele (wheel, bloccato, sudo) e root con la chiave SSH.
set -euo pipefail
cd "$(dirname "$0")/.."
IMG="${1:?uso: iso-post-prova.sh <immagine>}"
post=$(python3 - <<'PY'
import tomllib,re
k=tomllib.load(open('disk_config/iso-mbp.toml','rb'))['customizations']['installer']['kickstart']['contents']
p=re.search(r'^%post --log[^\n]*\n(.*?)^%end',k,re.S|re.M).group(1)
print('\n'.join(l for l in p.splitlines() if not l.startswith('bootc switch')))
PY
)
sudo podman run --rm -i "$IMG" bash -s <<SCRIPT
rm -rf /var/home /var/roothome  # come all'installazione: non esistono ancora
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIProvaChiaveExtraSoloPerIlTest prova' > /etc/mbp-os-chiavi-extra
$post
echo "== verifica"
set -e
id daniele
id -nG daniele | grep -qw wheel
passwd -S daniele | grep -Eq ' (L|LK) '
test -s /var/home/daniele/.ssh/authorized_keys
[ "\$(stat -c %U /var/home/daniele/.ssh/authorized_keys)" = daniele ]
grep -q ProvaChiaveExtra /var/home/daniele/.ssh/authorized_keys
grep -q ProvaChiaveExtra /var/roothome/.ssh/authorized_keys
test ! -e /etc/mbp-os-chiavi-extra
test -s /etc/sudoers.d/90-daniele
[ "\$(cat /etc/hostname)" = macbook-linux ]
[ "\$(/usr/libexec/mbp-os/modo leggi)" = server ]
echo "PROVA %post: OK"
SCRIPT
