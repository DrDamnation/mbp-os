#!/usr/bin/env bash
# Aggiunge alla ISO di CI i file locali (segreti) che l'installazione copia sul Mac:
#   <cartella-segreti>/wifi.nmconnection        obbligatorio (profilo Wi-Fi di casa)
#   <cartella-segreti>/authorized_keys.extra    facoltativo (chiavi SSH in più, es. per la prova in VM)
# Uso: tools/prepara-iso.sh <iso-ci> <cartella-segreti> <iso-uscita>
# Gira mkksiso (lorax) in un container Fedora 44: serve docker o podman (CONTAINER=...).
set -euo pipefail
die() { echo "prepara-iso: $*" >&2; exit 2; }
(( $# == 3 )) || die "uso: prepara-iso.sh <iso-ci> <cartella-segreti> <iso-uscita>"
iso=$1 sec=$2 out=$3
[[ -s $iso ]] || die "ISO non trovata: $iso"
wifi=$sec/wifi.nmconnection
[[ -s $wifi ]] || die "manca il profilo Wi-Fi $wifi: senza, dopo l'installazione il Mac non va in rete"
grep -q '^psk=.\{8,\}' "$wifi" || die "il profilo Wi-Fi $wifi non ha una riga psk= valida"  # secrets-scan: ok (controllo, non un valore)
grep -q '^ssid=.' "$wifi" || die "il profilo Wi-Fi $wifi non ha una riga ssid="
[[ ${PREPARA_SOLO_CONTROLLI:-0} == 1 ]] && { echo "prepara-iso: controlli OK"; exit 0; }

lav=$(mktemp -d); trap 'rm -rf "$lav"' EXIT
mkdir -p "$lav/mbp-os"
install -m 600 "$wifi" "$lav/mbp-os/wifi.nmconnection"
[[ -s $sec/authorized_keys.extra ]] && install -m 600 "$sec/authorized_keys.extra" "$lav/mbp-os/authorized_keys.extra"
cp "$iso" "$lav/in.iso"

ct=${CONTAINER:-$(command -v podman >/dev/null && echo podman || echo docker)}
MSYS_NO_PATHCONV=1 "$ct" run --rm --privileged -v "$lav:/lav" registry.fedoraproject.org/fedora:44 bash -euc '
    dnf -y -q install lorax xorriso >/dev/null
    # --skip-mkefiboot: il boot non cambia (aggiungiamo solo una cartella) e niente loop device
    mkksiso --skip-mkefiboot -a /lav/mbp-os /lav/in.iso /lav/out.iso
    xorriso -indev /lav/out.iso -find /mbp-os -type f 2>/dev/null | grep -q wifi.nmconnection
'
mv "$lav/out.iso" "$out"
sha256sum "$out"
