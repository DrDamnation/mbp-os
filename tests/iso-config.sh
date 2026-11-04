#!/usr/bin/env bash
# Controlli statici sul kickstart dell'ISO: solo sul MacBookPro10,2, solo sul suo SSD, niente segreti.
set -u
cd "$(dirname "$0")/.."
source tests/lib.sh
K=disk_config/iso-mbp.toml

section "Disco"
check "pre-controllo che blocca l'installazione" grep -q '%pre --erroronfail' "$K"
check "sceglie il disco per modello" grep -q '"APPLE SSD SM256E"' "$K"
check "si ferma se i dischi giusti non sono esattamente 1" grep -q '\[ \$# -ne 1 \]' "$K"
check "disco incluso dal %pre" grep -qx '%include /tmp/disco.ks' "$K"
check "nessun nome di disco fisso" ! grep -Eq '\b(sd[a-z]|nvme[0-9]n[0-9])\b' "$K"
check "xfs senza swap e senza /home separata" grep -q 'autopart --noswap --nohome --type=plain --fstype=xfs' "$K"

section "Macchina giusta"
check "controlla il modello del Mac" grep -q '"MacBookPro10,2"' "$K"

section "Accesso senza segreti"
check "chiave per daniele" grep -Eq "^echo 'ssh-ed25519 [A-Za-z0-9+/=]+' > /var/home/daniele/.ssh/authorized_keys" "$K"
check "chiave per root (seconda via)" grep -Eq "^echo 'ssh-ed25519 [A-Za-z0-9+/=]+' > /var/roothome/.ssh/authorized_keys" "$K"
check "niente user/sshkey dell'installer" ! grep -Eq '^(user|sshkey) ' "$K"
check "gruppi copiati da /usr/lib/group" grep -q 'grep "^$g:" /usr/lib/group >> /etc/group' "$K"
check "daniele bloccato (solo chiave)" grep -qx 'passwd -l daniele' "$K"
check "sudo senza password" grep -q "daniele ALL=(ALL) NOPASSWD: ALL" "$K"
check "password di root bloccata" grep -qx 'rootpw --lock' "$K"
check "nessuna password in chiaro" ! grep -Eq -- '--(plaintext|password|iscrypted)|psk=' "$K"
check "nessuna chiave privata" ! grep -q 'PRIVATE' "$K"

section "Chiavetta e sistema"
check "%post --nochroot legge la chiavetta" grep -q '^%post --nochroot' "$K"
NOCHROOT=$(awk '/^%post --nochroot/{f=1} f{print} f&&/^%end/{exit}' "$K")
check "profilo Wi-Fi con permessi 600 root" grep -q 'chown 0:0 "$nm/casa.nmconnection" && chmod 600' <<<"$NOCHROOT"
check "niente 'install' nel %post --nochroot (non esiste nell'installer)" bash -c '! grep -Eq "(^|[[:space:];&|])install " <<<"$1"' _ "$NOCHROOT"
check "il %post --nochroot cerca il deployment ostree" grep -q 'ostree/deploy/\*/deploy/\*.0' <<<"$NOCHROOT"
check "hostname macbook-linux" grep -qx 'echo macbook-linux > /etc/hostname' "$K"
check "modo iniziale server" grep -qx "echo 'MODO=server' > /etc/mbp-os/mbp.conf" "$K"
check "segue l'immagine firmata" grep -q 'bootc switch --mutate-in-place --enforce-container-sigpolicy --transport registry ghcr.io/drdamnation/mbp-os:stable' "$K"
check "il %post non si ferma al primo errore" ! grep -q '%post --erroronfail' "$K"

section "TOML"
py=""
for p in python3 python; do "$p" -c 'import tomllib' 2>/dev/null && { py=$p; break; }; done
check "si legge come TOML" "${py:-python3}" -c "import tomllib; tomllib.load(open('$K','rb'))"

finish
