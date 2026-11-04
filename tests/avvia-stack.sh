#!/usr/bin/env bash
# Test di avvia-stack con docker finto. Uso: bash tests/avvia-stack.sh
set -u
cd "$(dirname "$0")/.."
source tests/lib.sh
S=system_files/usr/libexec/mbp-os/avvia-stack
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/uno" "$tmp/rotto" "$tmp/tre"
cat > "$tmp/docker" <<D
#!/bin/sh
echo "\$PWD \$*" >> "$tmp/chiamate"
case "\$PWD" in */rotto) exit 1;; esac
D
chmod +x "$tmp/docker"
esegui() { DOCKER="$tmp/docker" bash "$S" "$1" > "$tmp/out" 2>&1; }

section "elenco con uno stack rotto"
printf '# commento\n\n%s\n%s  # nota\n%s\n' "$tmp/uno" "$tmp/rotto" "$tmp/tre" > "$tmp/conf"
check "esce con errore se uno fallisce" ! esegui "$tmp/conf"
check "il terzo parte anche se il secondo è rotto" grep -q "tre compose up -d" "$tmp/chiamate"
check "tre tentativi" bash -c "[ \$(wc -l < '$tmp/chiamate') = 3 ]"
check "riepilogo" grep -q 'OK 2 / FALLITI 1' "$tmp/out"
check "nomina lo stack rotto" grep -q "fallito: .*rotto" "$tmp/out"

section "elenco mancante"
rm -f "$tmp/chiamate"
check "esce senza errore" esegui "$tmp/manca.conf"
check "non chiama docker" test ! -e "$tmp/chiamate"

section "cartella inesistente"
printf '%s\n%s\n' "$tmp/manca" "$tmp/uno" > "$tmp/conf"
check "errore" ! esegui "$tmp/conf"
check "conta come fallita" grep -q 'OK 1 / FALLITI 1' "$tmp/out"

finish
