# Variabili condivise dagli step. Ogni step fa: source "$(dirname "$0")/vars.sh"
set -ouex pipefail

FEDORA_VERSION=44

# mbpfan (non è nei repo Fedora): sorgenti upstream, versione e sha256 fissati
MBPFAN_VERSION=2.4.0
MBPFAN_SHA256=e1cdcffaba52be215ae40a8568949190866d500d6ae2a1e96b71ab5372f3580b
DMS_COPR=avengemedia/dms
DMS_DEPS_COPR=avengemedia/danklinux
