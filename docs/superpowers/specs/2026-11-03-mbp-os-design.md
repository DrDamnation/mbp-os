# mbp-os — OS su misura per il MacBook Pro 2012 con schermo rotto

Stato: **in attesa di approvazione** di Daniele. Data: 2026-11-03.
Fratelli: `air-os` (MacBook Air 2017) e `nas-os` (Asustor AS6702T). Stessa famiglia: immagine bootc firmata, repo pubblico + repo privato di configurazione.

## 1. Perché

Il MacBook Pro 13" Retina 2012 ha il pannello interno rotto e oggi gira Ubuntu 24.04 messo a mano, con una serie di trappole già pagate (schermo nero da `nomodeset`, driver Wi-Fi `wl` che non compila sui kernel nuovi, GRUB in attesa infinita senza tastiera). Daniele lo vuole usare **in base alle esigenze**: o come **PC attaccato con cavo HDMI**, o come **serverino**. Vuole lo stesso lavoro fatto per air-os e nas-os: sistema **su misura, preconfigurato, con accesso remoto con chiave**.

## 2. Obiettivi, non-obiettivi, anti-obiettivi

**Obiettivi**
- Un'immagine bootc `ghcr.io/drdamnation/mbp-os:stable`, firmata, aggiornabile con ritorno indietro (rollback).
- **Interruttore di modo nella configurazione** (decisione Daniele): `pc` oppure `server`.
- Accesso remoto **solo con chiave SSH**, attivo dal primo avvio, in entrambi i modi, anche via Tailscale.
- Tutte le correzioni hardware già scoperte sono nell'immagine, non sistemate a mano.
- Installazione senza interventi: chi è davanti al Mac infila la chiavetta, tiene premuto Option, sceglie la chiavetta, e basta.

**Non-obiettivi**
- Supportare altri computer.
- Servizi Docker precaricati nell'immagine: si aggiungono dalla configurazione.
- Cifratura del disco.
- Uso a batteria (la batteria è a fine vita, 57% della capacità): il Mac sta alla corrente.

**Anti-obiettivi** (fallimento anche se "funziona")
- Dopo l'installazione o un aggiornamento il Mac non è raggiungibile da remoto e serve andarci fisicamente (lezione della prima installazione di nas-os).
- Consegnare una ISO non provata.
- Password, chiavi private, password Wi-Fi o dati personali nel repo pubblico.
- Il Wi-Fi sparisce dopo un aggiornamento.
- Far digitare comandi a Daniele: tutto automatizzato, al massimo tasti da premere nominati come appaiono.

## 3. Hardware

Da note (Ubuntu, agosto 2026) — **da riverificare dal vivo prima del piano** (il Mac oggi è spento/offline):
- MacBookPro10,2 (A1425), grafica Intel `i915`, pannello interno `eDP-1` rotto. Uscita HDMI funzionante con `i915` caricato.
- Wi-Fi Broadcom che oggi funziona con il driver proprietario `wl` (interfaccia `wlp3s0`). Chip esatto: da leggere con `lspci -nn`.
- Niente porta Ethernet (si può usare l'adattatore USB-Ethernet RTL8153 di air-os come ripiego).
- Ventole: `mbpfan` tarato low=55 high=65 max=84 (a pieno carico 79 °C, nessun throttling).
- SMC delicato: si è piantato dopo ripetuti stacchi di corrente, si è ripreso con una scarica completa.
- Disco, RAM, presenza di macOS o altre partizioni: da leggere dal vivo.

## 4. Decisioni

| Tema | Decisione | Di chi |
|---|---|---|
| Uso | PC su HDMI **oppure** serverino | Daniele |
| Scelta del modo | Interruttore nella configurazione | Daniele |
| Accesso | Remoto con chiave, preconfigurato | Daniele |
| Approccio | Immagine bootc come air-os/nas-os | Daniele |
| Base | `ghcr.io/ublue-os/base-main:44` + `kmod-wl` da `ghcr.io/ublue-os/akmods:main-44`, come air-os; repo autonomo (non `FROM air-os`, che contiene cose solo dell'Air) | Claude |
| Desktop modo `pc` | niri + DMS + greetd come air-os | Claude |
| Cifratura | Nessuna (password all'avvio = server irraggiungibile) | Claude |
| Disco | Intero disco interno a mbp-os, Ubuntu cancellata, dopo copia fuori dei dati utili | Claude, da confermare dopo aver visto il disco |
| Nome | `mbp-os` (pubblico) + `mbp-config` (privato) | Claude |

## 5. Architettura

Come air-os/nas-os: repo pubblico `DrDamnation/mbp-os` creato da `ublue-os/image-template`, build GitHub Actions, push su ghcr.io, firma cosign con la policy di verifica dentro l'immagine; repo privato `DrDamnation/mbp-config` per i file di configurazione (stack compose, impostazioni), scaricato sul Mac con deploy key in sola lettura (`ujust config`, come `ujust air-config`).

Scanner anti-segreti e dati personali **identico** a quello di air-os/nas-os (`tests/secrets-scan.sh`, hook `.githooks`, `.secrets-scan-extra` fuori git, segreto CI `SECRETS_SCAN_EXTRA`, gitleaks). Commit con l'email noreply di DrDamnation. Nota: le Actions sui repo privati oggi non partono (problema di fatturazione GitHub) → `mbp-config` solo con hook locale.

## 6. Contenuto dell'immagine

### 6.1 Hardware (dalle trappole già pagate)
- Karg `video=eDP-1:d` (spegne il pannello rotto), **mai** `nomodeset`. Il nome del connettore va verificato su Fedora.
- `kmod-wl` precompilato: niente DKMS, quindi niente problema objtool.
- `mbpfan` con la taratura sopra (se non è nei repo Fedora 44: builder decide come portarlo), `applesmc`.
- Attesa del menu di avvio sempre a tempo (mai attesa infinita di un tasto dopo un avvio fallito).
- Coperchio chiuso: **ignorato** in entrambi i modi (lo schermo interno è comunque rotto).
- Il controllo in build fallisce se `wl` manca nell'immagine (come air-os).

### 6.2 Interruttore di modo
- Un file di impostazioni sul Mac (es. `/etc/mbp-os/mbp.conf`, `MODO=pc|server`) è l'unica fonte di verità per il modo. *(Scelta Claude)* Il modo **non** sta in `mbp-config` (la deploy key è in sola lettura e `ujust config` annullerebbe `ujust modo`): `mbp-config` contiene solo gli stack e le loro impostazioni, e `ujust config` non tocca mai il modo.
- `ujust modo pc` / `ujust modo server`: cambia il file e chiede/esegue il riavvio. Il modo vale dal riavvio.
- **pc**: si avvia l'interfaccia grafica (greetd → niri) sull'HDMI. Docker installato ma i suoi stack fermi.
- **server**: avvio senza grafica (multi-user), partono gli stack Docker elencati in configurazione.
- **In entrambi**: sshd, Tailscale, ventole, aggiornamenti.
- Modo predefinito alla prima installazione: `server` *(scelta Claude: il Mac nasce senza monitor attaccato)*.
- Come implementarlo (default target, unità condizionate, generatore systemd): scelta del builder.

### 6.3 Serverino
- Docker + Compose. Avvio degli stack come `nas-stacks`: elenco in configurazione, un'unità che li avvia in ordine e salta quelli rotti senza bloccare gli altri.
- Nessuno stack predefinito.
- Tailscale installato; l'adesione alla tailnet (chiave/login, firma Tailnet Lock) si fa dopo l'installazione via SSH in LAN, non con chiavi nel repo.

### 6.4 Accesso
- sshd: solo chiave, `PasswordAuthentication no`, `KbdInteractiveAuthentication no`.
- **Due vie**: chiave pubblica per `daniele` e per `root` (lezione nas-os). La chiave è la stessa di `github.com/DrDamnation.keys`.
- *(Scelta Claude)* `daniele` **senza password**, con sudo senza password: si entra solo con la chiave, quindi la password non aggiunge protezione da remoto e Daniele non deve digitare niente. In modo `pc` l'HDMI fa login automatico come `daniele` (il Mac sta in casa; chi ha accesso fisico ha comunque la macchina). Se in futuro si vuole una password, si imposta dopo.

### 6.5 Aggiornamenti
- Come air-os: aggiornamento manuale (`ujust update` / `bootc upgrade`), rollback con riavvio. *(Scelta Claude: per un serverino si potrebbe accendere il timer automatico; per ora spento, come air-os.)*

## 7. Installazione

- ISO Anaconda dall'immagine (bootc-image-builder, runner `ubuntu-24.04`, rootfs btrfs dichiarato: lezioni air-os).
- Kickstart **completamente automatico**: disco interno intero, nessuna schermata. Protezione: il %pre controlla il modello DMI (`MacBookPro10,2`) e il disco atteso, altrimenti si ferma senza toccare niente.
- Utente `daniele` e chiavi creati nel %post (lezione nas-os: gli utenti dell'immagine non sono visibili all'installer).
- **Wi-Fi al primo avvio**: la password Wi-Fi non può stare nella ISO pubblica. *(Proposta Claude)* La ISO di CI non contiene la rete; il file NetworkManager con la password viene aggiunto localmente sul PC alla chiavetta (o alla ISO costruita in locale) da un file fuori git, e il %post lo copia. Ripiego: adattatore USB-Ethernet RTL8153 (se a portata il giorno dell'installazione; la via principale è il profilo Wi-Fi, che va quindi provato e la preparazione della chiavetta deve fallire in modo evidente se il profilo manca). Il builder sceglie il meccanismo, purché nessun segreto finisca in git o negli artefatti CI.
- **Prove obbligatorie prima della consegna**: %post provato nell'immagine vera in CI (`iso-post-prova.sh` come nas-os); installazione completa della ISO in VM (QEMU) fino al login SSH con chiave come `daniele` e come `root`.
- Prima di cancellare Ubuntu: copia fuori macchina di `/root/salvataggio-*`, della configurazione netplan e di qualunque dato in `/home` (copia di sicurezza della password Wi-Fi).
- Chiavetta: la Kingston già usata, scritta via PowerShell RunAs su `\\.\PhysicalDriveN` verificando il seriale e lo sha256 riletto.

## 7bis. Dove vive
- **A casa** (Daniele, 2026-11-03), rete 192.168.33.x. Il profilo Wi-Fi da mettere sulla chiavetta è quello di casa: SSID e password si leggono dal Mac (netplan attuale) e si verifica che corrispondano alla rete di casa di oggi. L'adesione a Tailscale e la firma Tailnet Lock si fanno dal PC in LAN via SSH dopo l'installazione.

## 8. Da verificare dal vivo prima del piano

Il Mac oggi è offline (Tailscale `macbook-linux` offline, SSH in timeout). Appena acceso:
- `lspci -nn` (chip Wi-Fi e grafica), `lsblk`, partizioni, firmware/boot EFI, RAM, rete Wi-Fi attuale (SSID e sottorete: la casa ora è 192.168.33.x).
- Cosa c'è da salvare su Ubuntu.

## 9. Lasciato al builder
- Organizzazione dei passi di build (riusare/copiare quelli di air-os).
- Meccanismo dell'interruttore di modo.
- Nomi dei comandi `ujust` oltre a `modo`, `config`, `update`.
