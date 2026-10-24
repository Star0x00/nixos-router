# fedora-bootc-router
#
# Scope so far: installable, bootable, DHCP, SSH, forwarding,
# plus dae (eBPF transparent proxy), Sub-Store (quadlet container) and the
# LAN DHCP server (systemd-networkd built-in).
# forgejo / remaining containers come later.
#
# Rule: static config goes in /usr; only machine-local state belongs in /etc.
FROM quay.io/fedora/fedora-bootc:44

# ── base packages ──
RUN dnf -y install --setopt=install_weak_deps=False \
        systemd-networkd \
        nftables \
        openssh-server \
        jq curl wget iproute iputils tcpdump bind-utils \
        tar rsync vim-enhanced less \
        podman glibc-langpack-en sudo \
    && dnf clean all \
    && rm -rf /var/cache/dnf /var/cache/libdnf5

# ── stage 3a: dae (eBPF transparent proxy) ──
# Upstream RPM repo; the package ships /usr/bin/dae plus a stock systemd unit
# and an example /etc/dae/config.dae (overwritten by rootfs/ below).
RUN curl -fsSL -o /etc/yum.repos.d/daeuniverse.repo https://daeuniverse.pages.dev/daeuniverse.repo \
    && dnf -y install --setopt=install_weak_deps=False dae \
    && dnf clean all \
    && rm -rf /var/cache/dnf /var/cache/libdnf5

# ── static config ──
COPY rootfs/ /

# ── Hy-MT2 1.8B translation model (served by llama-server) ──
# Baked into the image instead of downloaded at boot so the service does not
# depend on the proxy being healthy. The 1.25bit/2bit variants need unmerged
# llama.cpp kernels (ggml-org/llama.cpp PR #22836 / #19357), so ship the plain
# Q4_K_M quant, which loads on the stock llama.cpp:server image.
RUN mkdir -p /usr/share/llama.cpp \
    && curl -fL --retry 3 --retry-delay 5 \
        -o /usr/share/llama.cpp/Hy-MT2-1.8B-Q4_K_M.gguf \
        https://huggingface.co/tencent/Hy-MT2-1.8B-GGUF/resolve/main/Hy-MT2-1.8B-Q4_K_M.gguf \
    && chmod 0444 /usr/share/llama.cpp/Hy-MT2-1.8B-Q4_K_M.gguf

# ── enable / mask (bootc cannot start units at build time) ──
RUN systemctl mask \
        NetworkManager.service \
        NetworkManager-wait-online.service \
        firewalld.service \
        systemd-resolved.service \
    && systemctl enable \
        systemd-networkd.service \
        systemd-networkd-wait-online.service \
        sshd.service \
        nftables.service \
        dae.service \
        dae-reload.timer
# Quadlet units under /usr/share/containers/systemd are generated at boot;
# their [Install] section makes them start without an explicit enable.

# ── machine identity ──
# systemd-resolved is masked, so /etc/resolv.conf must be a real file: the base
# image ships it as a symlink to /run/systemd/resolve/stub-resolv.conf, which is
# only created by resolved at runtime (a dangling symlink means no resolver).
# Host queries go through dae's eBPF DNS interception, same as the old NixOS
# setup; LAN clients get 10.10.10.1 from the DHCP server and dae answers them.
RUN echo 'router' > /etc/hostname \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && printf 'LANG=en_US.UTF-8\n' > /etc/locale.conf \
    && rm -f /etc/resolv.conf \
    && printf 'nameserver 223.5.5.5\nnameserver 223.6.6.6\n' > /etc/resolv.conf

# No accounts are created here on purpose: the only login is root via the key in
# /etc/ssh/authorized_keys/root. Extra accounts are created manually on the
# running system (they land in /etc + /var/home, which survive upgrades).

# ── initramfs (r8152 must be present in the initrd) ──
# Rerun this step after touching /usr/lib/dracut/dracut.conf.d.
RUN set -eux; \
    kver=$(ls /usr/lib/modules); \
    DRACUT_NO_XATTR=1 dracut -vf "/usr/lib/modules/${kver}/initramfs.img" "${kver}"

# ── structural validation ──
RUN bootc container lint
