#!/usr/bin/env bash
# Prova d'installazione completa in VM (QEMU+OVMF+KVM), fingendo di essere il MacBook:
# DMI MacBookPro10,2, SSD ATA "APPLE SSD SM256E", ISO su chiavetta USB.
# Uso: tests/vm/installa-e-prova.sh <iso-di-ci>      (pensato per GitHub Actions, ubuntu-24.04)
set -euo pipefail
cd "$(dirname "$0")/../.."
source tests/lib.sh
ISO_CI=${1:?uso: installa-e-prova.sh <iso>}
W=${VM_DIR:-$PWD/vm-prova}; mkdir -p "$W/sec"
OVMF_CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
OVMF_VARS=/usr/share/OVMF/OVMF_VARS_4M.fd

# --- chiavetta come quella vera, con profilo Wi-Fi finto e una chiave SSH solo per la prova
ssh-keygen -q -t ed25519 -N '' -f "$W/chiave" <<<y >/dev/null
cp "$W/chiave.pub" "$W/sec/authorized_keys.extra"
printf '[connection]\nid=casa\ntype=wifi\n\n[wifi]\nmode=infrastructure\nssid=prova-vm\n\n[wifi-security]\nkey-mgmt=wpa-psk\npsk=solo-per-la-prova-vm\n' > "$W/sec/wifi.nmconnection"
tools/prepara-iso.sh "$ISO_CI" "$W/sec" "$W/chiavetta.iso"
set +e  # da qui contano i check: un comando che fallisce non deve chiudere la prova

vm() {  # vm <disco> <modello> <con-chiavetta 0/1> [altri argomenti qemu]
    local disco=$1 modello=$2 usb=$3; shift 3
    local a=(-machine q35,accel=kvm -cpu host -m 4096 -smp 2
        -drive if=pflash,format=raw,readonly=on,file=$OVMF_CODE
        -drive if=pflash,format=raw,file=$W/vars.fd
        -smbios "type=1,manufacturer=Apple Inc.,product=MacBookPro10,,2"
        -device ahci,id=ahci
        -drive id=ssd,file=$disco,if=none,format=raw
        -device "ide-hd,drive=ssd,bus=ahci.0,model=$modello,bootindex=1"
        -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=n0
        -display none -monitor unix:$W/mon.sock,server,nowait)
    if (( usb )); then
        a+=(-device qemu-xhci -drive id=usb,file=$W/chiavetta.iso,if=none,format=raw,readonly=on
            -device usb-storage,drive=usb,removable=on,bootindex=0 -no-reboot)
    fi
    exec qemu-system-x86_64 "${a[@]}" "$@"
}
foto() { echo "screendump $W/$1.ppm" | socat - "UNIX-CONNECT:$W/mon.sock" >/dev/null 2>&1 || true; }
S() { ssh -i "$W/chiave" -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o BatchMode=yes "$@"; }
aspetta_ssh() {  # aspetta_ssh <secondi>
    local fine=$((SECONDS + $1))
    until S daniele@127.0.0.1 true 2>/dev/null; do (( SECONDS > fine )) && return 1; sleep 5; done
}
diagnosi() {  # legge dal disco della VM (spenta) journal e log dell'installazione
    local out=$W/diagnosi.txt m=$W/mnt dev
    pkill -f qemu-system-x86_64 2>/dev/null; sleep 3
    dev=$(sudo losetup -fP --show "$W/mac.img") || return 0
    sudo partprobe "$dev" 2>/dev/null; sleep 2
    {
        echo "### partizioni"; sudo lsblk -f "$dev"
        for p in "$dev"p*; do
            mkdir -p "$m"; sudo mount -o ro "$p" "$m" 2>/dev/null || continue
            echo; echo "########## $p"; sudo ls "$m"
            sudo find "$m" -maxdepth 8 \( -name 'mbp-os-post*.log' -o -name 'installazione-chiavetta.log' -o -name 'fstab' -o -path '*loader/entries/*.conf' \) 2>/dev/null |
                while read -r f; do echo "----- $f"; sudo cat "$f"; done
            for j in $(sudo find "$m" -maxdepth 6 -type d -path '*/var/log/journal' 2>/dev/null); do
                echo "----- journal $j"
                sudo journalctl --directory "$j" -b -1 --no-pager -p warning 2>/dev/null | tail -150
                sudo journalctl --directory "$j" --no-pager -o short-monotonic 2>/dev/null | grep -iE 'fail|emergency|error|mount|dependency' | tail -150
            done
            for a in $(sudo find "$m" -maxdepth 6 -type d -path '*/var/log/anaconda' 2>/dev/null); do
                echo "----- anaconda $a"; sudo tail -80 "$a/journal.log" "$a/program.log" "$a/storage.log" 2>/dev/null
            done
            sudo umount "$m"
        done
    } > "$out" 2>&1
    sudo losetup -d "$dev"
    echo "diagnosi scritta in $out ($(wc -l < "$out") righe)"
}
gpt_vuoto() { [[ $(dd if="$1" bs=1 skip=512 count=8 2>/dev/null) != "EFI PART" ]]; }

if [[ ${SALTA_DISCO_SBAGLIATO:-0} == 1 ]]; then
    echo "ATTENZIONE: controllo disco sbagliato saltato (solo per i giri di diagnosi)"
else
section "Disco sbagliato: l'installazione non deve toccare niente"
truncate -s 64G "$W/altro.img"; cp "$OVMF_VARS" "$W/vars.fd"
vm "$W/altro.img" "Samsung SSD 860" 1 & q=$!
sleep 600; foto disco-sbagliato; kill "$q" 2>/dev/null || true; wait "$q" 2>/dev/null || true
check "disco di un altro modello lasciato vuoto" gpt_vuoto "$W/altro.img"
rm -f "$W/altro.img"
fi

pkill -f qemu-system-x86_64 2>/dev/null; sleep 2
section "Installazione automatica"
truncate -s 64G "$W/mac.img"; cp "$OVMF_VARS" "$W/vars.fd"
vm "$W/mac.img" "APPLE SSD SM256E" 1 & q=$!
fine=$((SECONDS + 3600))
while kill -0 "$q" 2>/dev/null; do
    (( SECONDS > fine )) && { foto installazione-bloccata; kill "$q"; break; }
    sleep 30
done
wait "$q" 2>/dev/null || true
check "il disco ora ha una tabella GPT" ! gpt_vuoto "$W/mac.img"

pkill -f qemu-system-x86_64 2>/dev/null; sleep 2
section "Primo avvio dal disco"
vm "$W/mac.img" "APPLE SSD SM256E" 0 & q=$!
trap 'foto ultimo-schermo; kill $q 2>/dev/null || true' EXIT
check "SSH come daniele con la chiave (entro 10 min)" aspetta_ssh 600
if (( _AIR_FAIL > 0 )) && ! S daniele@127.0.0.1 true 2>/dev/null; then
    foto ultimo-schermo; trap - EXIT; diagnosi
    echo "Il sistema installato non risponde: inutile proseguire, vedi diagnosi.txt"; finish; exit 1
fi
check "SSH come root con la chiave" S root@127.0.0.1 true
check "sudo senza password" S daniele@127.0.0.1 sudo -n true
check "SSH con password rifiutato" bash -c "! ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no -o PreferredAuthentications=password,keyboard-interactive -o BatchMode=yes -o ConnectTimeout=5 daniele@127.0.0.1 true"
check "hostname macbook-linux" bash -c "[ \"\$(ssh -i '$W/chiave' -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null daniele@127.0.0.1 hostname)\" = macbook-linux ]"
v() { S daniele@127.0.0.1 "$1" 2>/dev/null; }
check "modo server" bash -c "[ \"\$(ssh -i '$W/chiave' -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null daniele@127.0.0.1 /usr/libexec/mbp-os/modo leggi)\" = server ]"
check "target multi-user" bash -c "ssh -i '$W/chiave' -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null daniele@127.0.0.1 systemctl get-default | grep -qx multi-user.target"
check "profilo Wi-Fi 600 root" bash -c "ssh -i '$W/chiave' -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null daniele@127.0.0.1 sudo stat -c '%a %U' /etc/NetworkManager/system-connections/casa.nmconnection | grep -qx '600 root'"
echo "--- dettagli Wi-Fi"; v 'sudo cat /etc/mbp-os/installazione-chiavetta.log; sudo ls -la /etc/NetworkManager/system-connections/; sudo cat /var/roothome/mbp-os-post.log 2>/dev/null | tail -20'
check "karg video=eDP-1:d" v 'grep -q "video=eDP-1:d" /proc/cmdline'
check "mai nomodeset" v '! grep -q nomodeset /proc/cmdline'
check "segue l'immagine firmata" v 'sudo bootc status --format json | grep -q "ghcr.io/drdamnation/mbp-os:stable"'
check "docker attivo" v 'systemctl is-active docker.service'
check "image-checks sul sistema installato" v 'sudo bash /usr/share/mbp-os/tests/image-checks.sh'

section "Modo pc"
v 'ujust modo pc </dev/null' >/dev/null; v 'sudo systemctl reboot' || true; sleep 20
check "torna su SSH" aspetta_ssh 300
check "target grafico" v 'systemctl get-default | grep -qx graphical.target'
echo "--- dettagli modo pc"; v 'for u in docker.service docker.socket mbp-stacks.service; do echo "$u: enabled=$(systemctl is-enabled $u) active=$(systemctl is-active $u) $(systemctl show -p LoadState -p FragmentPath $u | tr "
" " ")"; done; ls -la /run/systemd/generator.early/ 2>&1 | head -20'
check "docker mascherato e fermo" v '[ "$(systemctl show -P LoadState docker.service)" = masked ] && ! systemctl is-active -q docker.service'
check "stack mascherati e fermi" v '[ "$(systemctl show -P LoadState mbp-stacks.service)" = masked ] && ! systemctl is-active -q mbp-stacks.service'
check "greetd partito" v 'systemctl is-active greetd.service'
check "SSH ancora attivo in modo pc" v true
v 'ujust modo server </dev/null' >/dev/null; v 'sudo systemctl reboot' || true; sleep 20
check "di nuovo server" aspetta_ssh 300
check "  ... multi-user" v 'systemctl get-default | grep -qx multi-user.target'

section "Avvio fallito: deve ripartire da solo"
v 'sudo grub2-editenv - set boot_success=0; sudo grub2-editenv - set boot_indeterminate=1' || true
v 'sudo systemctl reboot' || true; sleep 20
check "torna su SSH senza tasti (entro 3 min)" aspetta_ssh 180

finish
