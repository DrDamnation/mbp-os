# Ricette mbp-os (ujust <nome>)

# Mostra o cambia il modo: ujust modo [pc|server] (vale dal riavvio)
[group('mbp-os')]
modo scelta="":
    #!/usr/bin/bash
    set -euo pipefail
    if [[ -z "{{ scelta }}" ]]; then
        echo "Modo attuale: $(/usr/libexec/mbp-os/modo leggi)"; exit 0
    fi
    sudo /usr/libexec/mbp-os/modo imposta "{{ scelta }}"
    echo "Modo impostato: {{ scelta }} (vale dal prossimo avvio)"
    if [[ -t 0 ]]; then
        read -r -p "Riavvio ora? [s/N] " r
        [[ $r == [sS] ]] && sudo systemctl reboot
    fi
    true

# Aggiorna il sistema all'ultima immagine (si applica al riavvio, rollback con un riavvio)
[group('mbp-os')]
update:
    sudo bootc upgrade

# Scarica/aggiorna la configurazione privata (stack Docker) da DrDamnation/mbp-config
[group('mbp-os')]
config azione="aggiorna":
    /usr/bin/mbp-config {{ azione }}
