# syntax=docker/dockerfile:1.7
ARG NODE_VERSION=20.19.5
ARG RUST_VERSION=1.93.0
ARG KAIROS_INIT_VERSION=v0.17.2
ARG UBUNTU_VERSION=26.04
ARG BASE_IMAGE=ubuntu:${UBUNTU_VERSION}

FROM node:${NODE_VERSION}-bookworm-slim AS web-builder
ARG PNPM_VERSION=10.15.0
WORKDIR /src
RUN corepack enable && corepack prepare "pnpm@${PNPM_VERSION}" --activate
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml ./
COPY apps/shell/package.json apps/shell/package.json
COPY packages/ui/package.json packages/ui/package.json
RUN pnpm install --frozen-lockfile
COPY apps/shell apps/shell
COPY packages/ui packages/ui
RUN pnpm --filter @dead-rose/shell build

FROM rust:${RUST_VERSION}-bookworm AS rust-builder
ENV CARGO_BUILD_JOBS=1
RUN apt-get update && apt-get install -y --no-install-recommends \
    libwebkit2gtk-4.1-dev libayatana-appindicator3-dev librsvg2-dev patchelf \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY Cargo.toml Cargo.lock rust-toolchain.toml ./
COPY crates crates
COPY apps/shell/src-tauri apps/shell/src-tauri
COPY --from=web-builder /src/apps/shell/dist apps/shell/dist
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    cargo build --locked --release --package dead-rose-core --package dead-rose-shell

FROM quay.io/kairos/kairos-init:${KAIROS_INIT_VERSION} AS kairos-init

FROM ${BASE_IMAGE}
ARG VERSION=0.1.0
ARG TARGETARCH=amd64
LABEL org.opencontainers.image.title="Dead Rose OS" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source="https://github.com/dead-rose-labs/dead-rose-os"
ENV DEBIAN_FRONTEND=noninteractive

RUN printf 'Acquire::Retries "5";\n' > /etc/apt/apt.conf.d/80-dead-rose-retries \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates systemd systemd-sysv dbus dbus-user-session udev kmod util-linux iproute2 \
    network-manager greetd cage seatd \
    libwebkit2gtk-4.1-0 librsvg2-2 \
    libegl-mesa0 libgl1-mesa-dri mesa-vulkan-drivers \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/* \
    && groupadd --system deadrose \
    && useradd --system --gid deadrose --home-dir /var/lib/dead-rose/ui --shell /usr/sbin/nologin deadrose \
    && usermod --append --groups video deadrose \
    && if getent group render >/dev/null; then usermod --append --groups render deadrose; fi

COPY --from=rust-builder /src/target/release/dead-rose-core /opt/dead-rose/bin/dead-rose-core
COPY --from=rust-builder /src/target/release/dead-rose-shell /opt/dead-rose/bin/dead-rose-shell
COPY os/rootfs/ /

RUN --mount=type=bind,from=kairos-init,src=/kairos-init,dst=/kairos-init \
    /kairos-init -l debug --model generic --version "${VERSION}"

RUN test -s /etc/kairos-release

# Kairos selects multi-user.target during its live initramfs stage. Keep
# graphical.target canonical for normal systemd boots, while attaching the
# same greetd unit to Kairos' appliance boot target as well.
RUN chmod 0755 /opt/dead-rose/bin/dead-rose-core /opt/dead-rose/bin/dead-rose-shell \
    && mkdir -p /etc/systemd/system/multi-user.target.wants /etc/systemd/system/graphical.target.wants \
    && ln -sfn /etc/systemd/system/dead-rose-core.service /etc/systemd/system/multi-user.target.wants/dead-rose-core.service \
    && ln -sfn /usr/lib/systemd/system/NetworkManager.service /etc/systemd/system/multi-user.target.wants/NetworkManager.service \
    && ln -sfn /usr/lib/systemd/system/greetd.service /etc/systemd/system/multi-user.target.wants/greetd.service \
    && ln -sfn /usr/lib/systemd/system/greetd.service /etc/systemd/system/graphical.target.wants/greetd.service \
    && ln -sfn /usr/lib/systemd/system/greetd.service /etc/systemd/system/display-manager.service \
    && ln -sfn /usr/lib/systemd/system/graphical.target /etc/systemd/system/default.target

RUN --mount=type=bind,source=tests/integration/image-sanity.sh,target=/tmp/image-sanity.sh,readonly \
    /bin/bash /tmp/image-sanity.sh

STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
