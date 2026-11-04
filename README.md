# mbp-os

Immagine bootc personale per un MacBook Pro 10,2 (Retina 13", 2012) con il **pannello interno rotto**.
Due modi, scelti con `ujust modo pc|server` (vale dal riavvio):

- **pc**: desktop niri sull'HDMI, login automatico.
- **server**: niente grafica, partono gli stack Docker elencati in `/etc/mbp-os/stacks.conf` (da `mbp-config`, privato).

In entrambi: SSH solo con chiave (anche root), Tailscale, ventole `mbpfan`, nessuna sospensione.
Wi-Fi BCM4331 col driver `wl` precompilato; pannello spento con `video=eDP-1:d` (mai `nomodeset`).

Immagine: `ghcr.io/drdamnation/mbp-os:stable`, firmata con cosign (`cosign.pub`).
Progetto e piano: `docs/superpowers/`. Nessun segreto in questo repo: lo controlla `tests/secrets-scan.sh`.
