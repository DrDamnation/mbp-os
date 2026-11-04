#!/usr/bin/env bash
# Test dei controlli di tools/prepara-iso.sh (senza costruire ISO). Uso: bash tests/prepara-iso.sh
set -u
cd "$(dirname "$0")/.."
source tests/lib.sh
P=tools/prepara-iso.sh
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
echo finta > "$tmp/ci.iso"; mkdir "$tmp/sec"
esce2() { PREPARA_SOLO_CONTROLLI=1 bash "$P" "$@" >/dev/null 2>"$tmp/err"; [[ $? == 2 ]]; }

section "controlli"
check "argomenti sbagliati: esce 2" esce2 "$tmp/ci.iso"
check "ISO mancante: esce 2" esce2 "$tmp/manca.iso" "$tmp/sec" "$tmp/out.iso"
check "senza profilo Wi-Fi: esce 2" esce2 "$tmp/ci.iso" "$tmp/sec" "$tmp/out.iso"
check "  ... e lo dice" grep -q "manca il profilo Wi-Fi" "$tmp/err"
printf '[wifi]\nssid=casa\n' > "$tmp/sec/wifi.nmconnection"
check "profilo senza psk: esce 2" esce2 "$tmp/ci.iso" "$tmp/sec" "$tmp/out.iso"  # secrets-scan: ok (valore finto del test)
printf '[wifi]\npsk=12345678\n' > "$tmp/sec/wifi.nmconnection"
check "profilo senza ssid: esce 2" esce2 "$tmp/ci.iso" "$tmp/sec" "$tmp/out.iso"
printf '[wifi]\nssid=casa\n[wifi-security]\npsk=12345678\n' > "$tmp/sec/wifi.nmconnection"
check "profilo valido: passa" env PREPARA_SOLO_CONTROLLI=1 bash "$P" "$tmp/ci.iso" "$tmp/sec" "$tmp/out.iso"

finish
