# Hardware del MacBook Pro (letto dal vivo il 2026-11-04, Ubuntu 24.04, kernel 7.0.0-30)

- DMI `product_name`: `MacBookPro10,2`
- Grafica: Intel HD 4000 `[8086:0166]` (i915). Connettori: `HDMI-A-1..3`, `DP-1..3`, `VGA-1`.
  Il pannello interno `eDP-1` non compare in `/sys/class/drm`: con `video=eDP-1:d` il kernel
  scrive `[drm] forcing eDP-1 connector off` e poi `failed to retrieve link info, disabling eDP`.
- Wi-Fi: Broadcom **BCM4331** `[14e4:4331]`, oggi col driver proprietario `wl`, interfaccia `wlp3s0`.
- `[14e4:16a3]` BCM57786: la funzione Ethernet non ha una porta fisica (il chip serve il lettore SD).
- SATA AHCI `[8086:1e03]`. Unico disco: `sda`, 233,8 GB, `/sys/block/sda/device/model` = `APPLE SSD SM256E`.
  Partizioni oggi: sda1 EFI 1 GB, sda2 ext4 (Ubuntu). **Nessun macOS** (resta solo una voce EFI "Mac OS X" orfana).
- RAM: 8 GB.
- Ventole: `mbpfan` **non installato** al 2026-11-04 (le ventole le gestisce l'SMC); temperature a riposo ~36 °C.
- Rete: Wi-Fi di casa, DHCP sulla rete 192.168.33.x.
