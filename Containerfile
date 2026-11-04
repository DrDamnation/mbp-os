# Contesto di build: script, file di sistema e test (non finiscono nell'immagine se non copiati)
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files
COPY tests /tests

# mbp-os: Fedora 44 atomica senza desktop, base Universal Blue
FROM ghcr.io/ublue-os/base-main:44

ARG GIT_SHA=unknown

# RPM dei moduli precompilati da Universal Blue (kmod-wl per il Wi-Fi Broadcom)
RUN --mount=type=bind,from=ctx,source=/,target=/ctx     --mount=type=bind,from=ghcr.io/ublue-os/akmods:main-44,source=/rpms,target=/tmp/akmods-rpms     --mount=type=bind,from=ghcr.io/ublue-os/akmods:main-44,source=/kernel-rpms,target=/tmp/kernel-rpms \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    GIT_SHA="${GIT_SHA}" /ctx/build.sh

RUN bootc container lint
