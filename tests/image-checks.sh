#!/usr/bin/env bash
# Controlli dentro l'immagine costruita (CI) o sul Mac installato.
# Uso: podman run --rm <image> bash /usr/share/mbp-os/tests/image-checks.sh
set -u
source "$(dirname "$0")/lib.sh"

KVER=$(ls /usr/lib/modules | head -1)
copr_attivi() {
    grep -l '^enabled=1' /etc/yum.repos.d/_copr*.repo 2>/dev/null | grep -v '_copr_ublue-os-akmods.repo'
}

section "Base"
check "Fedora 44" grep -q 'VERSION_ID=44' /etc/os-release
check "nessun repo COPR nostro attivo" ! copr_attivi
check "timer bootc update spento" ! systemctl is-enabled bootc-fetch-apply-updates.timer
check "timer rpm-ostree automatico spento" ! systemctl is-enabled rpm-ostreed-automatic.timer
check "build info" test -s /usr/share/mbp-os/build-info

section "Firma"
check "chiave pubblica mbp-os" test -s /etc/pki/containers/mbp-os.pub
check "policy firma mbp-os" jq -e '.transports.docker["ghcr.io/drdamnation/mbp-os"][0].type == "sigstoreSigned"' /etc/containers/policy.json
check "sigstore attachments" grep -q 'ghcr.io/drdamnation/mbp-os' /etc/containers/registries.d/mbp-os.yaml

section "Mac"
check "wl per il kernel dell'immagine ($KVER)" modinfo -k "$KVER" wl
check "karg video=eDP-1:d" grep -q 'video=eDP-1:d' /usr/lib/bootc/kargs.d/10-mbp.toml
check "mai nomodeset" ! grep -rq nomodeset /usr/lib/bootc/kargs.d
check "root xfs" grep -q 'type = "xfs"' /usr/lib/bootc/install/00-mbp.toml
check "mbpfan presente" test -x /usr/sbin/mbpfan
check "mbpfan abilitato" systemctl is-enabled mbpfan.service
for v in 'low_temp = 55' 'high_temp = 65' 'max_temp = 84'; do
    check "mbpfan $v" grep -qx "$v" /etc/mbpfan.conf
done
for k in HandleLidSwitch HandleLidSwitchExternalPower HandleLidSwitchDocked; do
    check "$k=ignore" grep -qx "$k=ignore" /usr/lib/systemd/logind.conf.d/10-mbp.conf
done
for t in sleep suspend hibernate hybrid-sleep; do
    check "$t.target mascherato" bash -c "[ \"\$(systemctl is-enabled $t.target 2>/dev/null)\" = masked ]"
done
check "niente gcc rimasto" ! rpm -q gcc

section "Modo"
check "generatore eseguibile" test -x /usr/lib/systemd/system-generators/mbp-modo-generator
check "senza mbp.conf vale server" bash -c '[ "$(/usr/libexec/mbp-os/modo leggi)" = server ]'
check "ricetta ujust modo" grep -q '^modo ' /usr/share/ublue-os/just/60-custom.just
check "build non forza il target grafico" bash -c '[ "$(readlink /etc/systemd/system/default.target 2>/dev/null)" != /usr/lib/systemd/system/graphical.target ]'

section "Server"
check "docker compose" docker compose version
for u in docker.service tailscaled.service sshd.service mbp-stacks.service; do
    check "$u abilitato" systemctl is-enabled "$u"
done
check "repo tailscale spento" ! grep -q '^enabled=1' /etc/yum.repos.d/tailscale.repo
# sshd -T vuole una chiave host: nell'immagine non c'è ancora (si crea al primo avvio)
hk=$(mktemp -u); ssh-keygen -q -t ed25519 -N '' -f "$hk" >/dev/null 2>&1
sshd_t() { /usr/sbin/sshd -T -h "$hk" 2>/dev/null; }
check "sshd: niente password" bash -c "$(declare -f sshd_t); hk=$hk; sshd_t | grep -qx 'passwordauthentication no'"
check "sshd: niente keyboard-interactive" bash -c "$(declare -f sshd_t); hk=$hk; sshd_t | grep -qx 'kbdinteractiveauthentication no'"
check "sshd: root solo con chiave" bash -c "$(declare -f sshd_t); hk=$hk; sshd_t | grep -Eqx 'permitrootlogin (without-password|prohibit-password)'"

check "mbp-config" test -x /usr/bin/mbp-config

section "Desktop"
for p in niri dms greetd; do check "$p" rpm -q "$p"; done
check "greetd abilitato" systemctl is-enabled greetd.service
check "login automatico daniele" grep -q 'user = "daniele"' /etc/greetd/config.toml
check "sessione iniziale" grep -q '^\[initial_session\]' /etc/greetd/config.toml

finish
