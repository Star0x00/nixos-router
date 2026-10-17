# fedora-bootc-router
#
# Scope so far: installable, bootable, DHCP, SSH, forwarding,
# plus dae (eBPF transparent proxy) and Sub-Store (quadlet container).
# kea / forgejo / remaining containers come later.
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
        podman glibc-langpack-en \
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
RUN echo 'router' > /etc/hostname \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && printf 'LANG=en_US.UTF-8\n' > /etc/locale.conf

RUN useradd -m -G wheel -s /bin/bash cyrene \
    && install -d -m 0700 -o cyrene -g cyrene /home/cyrene/.ssh \
    && cp /etc/ssh/authorized_keys/root /home/cyrene/.ssh/authorized_keys \
    && chown cyrene:cyrene /home/cyrene/.ssh/authorized_keys \
    && chmod 0600 /home/cyrene/.ssh/authorized_keys

# ── initramfs (r8152 must be present in the initrd) ──
# Rerun this step after touching /usr/lib/dracut/dracut.conf.d.
RUN set -eux; \
    kver=$(ls /usr/lib/modules); \
    DRACUT_NO_XATTR=1 dracut -vf "/usr/lib/modules/${kver}/initramfs.img" "${kver}"

# ── structural validation ──
RUN bootc container lint
