# fedora-bootc-router — 骨架镜像
#
# 范围：可安装、可启动、能 DHCP、能 SSH、能转发。
# 不含 kea / dae / forgejo / 任何容器。服务后续逐个加。
#
# 规则：静态配置进 /usr，机器本地状态才进 /etc。
FROM quay.io/fedora/fedora-bootc:44

# ── 基础包 ──
RUN dnf -y install --setopt=install_weak_deps=False \
        systemd-networkd \
        nftables \
        openssh-server \
        jq curl wget iproute iputils tcpdump bind-utils \
        tar rsync vim-enhanced less \
        podman \
    && dnf clean all \
    && rm -rf /var/cache/dnf /var/cache/libdnf5

# ── 静态配置 ──
COPY rootfs/ /

# ── enable / mask（bootc 里不能 start，只能 enable / mask）──
RUN systemctl mask \
        NetworkManager.service \
        NetworkManager-wait-online.service \
        firewalld.service \
        systemd-resolved.service \
    && systemctl enable \
        systemd-networkd.service \
        systemd-networkd-wait-online.service \
        sshd.service \
        nftables.service

# ── 机器身份 ──
RUN echo 'router' > /etc/hostname \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && printf 'LANG=en_US.UTF-8\n' > /etc/locale.conf

RUN useradd -m -G wheel -s /bin/bash cyrene \
    && install -d -m 0700 -o cyrene -g cyrene /home/cyrene/.ssh \
    && cp /etc/ssh/authorized_keys/root /home/cyrene/.ssh/authorized_keys \
    && chown cyrene:cyrene /home/cyrene/.ssh/authorized_keys \
    && chmod 0600 /home/cyrene/.ssh/authorized_keys

# ── initramfs（r8152 必须在 initrd 里）──
# 改动 /usr/lib/dracut/dracut.conf.d 后必须重跑这一步。
RUN set -eux; \
    kver=$(ls /usr/lib/modules); \
    DRACUT_NO_XATTR=1 dracut -vf "/usr/lib/modules/${kver}/initramfs.img" "${kver}"

# ── 结构校验 ──
RUN bootc container lint
