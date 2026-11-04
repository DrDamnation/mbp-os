#!/usr/bin/env bash
# Test di modo e del generatore con file finti. Uso: bash tests/modo.sh
set -u
cd "$(dirname "$0")/.."
source tests/lib.sh
M=$PWD/system_files/usr/libexec/mbp-os/modo
G=$PWD/system_files/usr/lib/systemd/system-generators/mbp-modo-generator
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export MBP_CONF=$tmp/mbp.conf
leggi() { bash "$M" leggi 2>"$tmp/err"; }
scrivi() { printf "$1" > "$MBP_CONF"; }
uguale() { [[ $(leggi) == "$1" ]]; }

section "leggi"
rm -f "$MBP_CONF"
check "file mancante -> server" uguale server
scrivi 'MODO=pc\n';            check "MODO=pc" uguale pc
scrivi 'MODO=pc\r\n';          check "CRLF" uguale pc
scrivi '  MODO = pc  \n';      check "spazi" uguale pc
scrivi 'MODO=pc # nota\n';     check "commento in coda" uguale pc
scrivi '# MODO=pc\n';          check "riga commentata -> server" uguale server
scrivi '\n';                   check "file vuoto -> server" uguale server
scrivi 'MODO=Server\n';        check "maiuscole -> server" uguale server
check "  ... con avviso" grep -q "non valido" "$tmp/err"
scrivi 'MODO=boh\n';           check "valore strano -> server" uguale server
check "  ... con avviso" grep -q "non valido" "$tmp/err"
scrivi 'MODO=server\nMODO=pc\n'; check "vale l'ultima riga" uguale pc

section "imposta"
scrivi 'ALTRO=1\nMODO=server\n'
check "imposta pc" bash "$M" imposta pc
check "ora è pc" uguale pc
check "conserva le altre righe" grep -qx 'ALTRO=1' "$MBP_CONF"
check "una sola riga MODO" bash -c "[ \$(grep -c '^MODO=' '$MBP_CONF') = 1 ]"
cp "$MBP_CONF" "$tmp/prima"
check "imposta boh rifiutato" ! bash "$M" imposta boh
check "  ... esce con 2" bash -c "bash '$M' imposta boh 2>/dev/null; [ \$? = 2 ]"
stesso() { [[ $(sha256sum < "$1") == $(sha256sum < "$2") ]]; }
check "  ... file invariato" stesso "$MBP_CONF" "$tmp/prima"
rm -f "$MBP_CONF"
check "imposta su file mancante" bash "$M" imposta server
check "  ... crea il file" uguale server

section "generatore"
gen() { rm -rf "$tmp/early"; MBP_MODO="$M" MBP_UNITDIR=/u bash "$G" "$tmp/n" "$tmp/early" "$tmp/l"; }
scrivi 'MODO=pc\n'; gen
check "pc: esce 0" gen
check "pc: default graphical" bash -c "[ \$(readlink '$tmp/early/default.target') = /u/graphical.target ]"
for u in docker.service docker.socket mbp-stacks.service; do
    check "pc: $u mascherato" bash -c "[ \$(readlink '$tmp/early/$u') = /dev/null ]"
done
scrivi 'MODO=server\n'; gen
check "server: default multi-user" bash -c "[ \$(readlink '$tmp/early/default.target') = /u/multi-user.target ]"
check "server: docker non mascherato" test ! -e "$tmp/early/docker.service"
scrivi 'MODO=pc\n'; chmod 000 "$MBP_CONF"
if [[ $(id -u) != 0 ]]; then
    check "file illeggibile: esce 0" gen
    check "file illeggibile: server" bash -c "[ \$(readlink '$tmp/early/default.target') = /u/multi-user.target ]"
fi
chmod 644 "$MBP_CONF"
check "modo che esplode: esce 0 e server" bash -c "rm -rf '$tmp/early'; MBP_MODO=/bin/false MBP_UNITDIR=/u bash '$G' x '$tmp/early' y && [ \$(readlink '$tmp/early/default.target') = /u/multi-user.target ]"

finish
