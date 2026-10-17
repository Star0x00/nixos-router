# fedora-bootc-router
#
# 构建顺序对应 stages/：
#   阶段 2 骨架：基础包 + 静态配置 + mask 冲突服务 + initramfs
#   阶段 3 服务：kea / dae / forgejo / 容器(quadlet)
#   阶段 4 安装：本文件不涉及，见 stages/04-install.md
#
# 规则：静态配置进 /usr，机器本地状态才进 /etc。
FROM quay.io/fedora/fedora-bootc:43

# ─────────────────────────── 阶段 2：骨架 ───────────────────────────
RUN dnf -y install --setopt=install_weak_deps=False \
        systemd-networkd \
        nftables \
        openssh-server \
        jq curl wget iproute iputils tcpdump bind-utils \
        tar rsync vim-enhanced less \
        podman \
    && dnf clean all \
    && rm -rf /var/cache/dnf /var/cache/libdnf5

# ─────────────────────────── 阶段 3：服务包 ───────────────────────────
# kea: Fedora 官方仓库
RUN dnf -y install --setopt=install_weak_deps=False kea \
    && dnf clean all && rm -rf /var/cache/dnf /var/cache/libdnf5

# dae: Dae Universe RPM 仓库（eBPF 透明代理）
RUN curl -fsSL -o /etc/yum.repos.d/daeuniverse.repo https://daeuniverse.pages.dev/daeuniverse.repo \
    && dnf -y install dae \
    && dnf clean all && rm -rf /var/cache/dnf /var/cache/libdnf5

# forgejo + runner: Fedora 官方仓库；若某版本缺失，退回上游 RPM/二进制
RUN dnf -y install --setopt=install_weak_deps=False forgejo forgejo-runner \
    || echo "forgejo 未在仓库中，阶段 3 需改为上游 RPM" 

# ─────────────────────────── 静态配置（全进 /usr 或 /etc）───────────────────────────
COPY rootfs/ /

# ─────────────────────────── enable / mask ───────────────────────────
# bootc 镜像里不能 systemctl start，只能 enable / mask。
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
        kea-dhcp4.service \
        dae.service \
        dae-reload.timer \
        podman.socket \
    && systemctl disable \
        bootc-fetch-apply-updates.timer || true

# ─────────────────────────── 机器身份 ───────────────────────────
RUN echo 'nixos-router' > /etc/hostname \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && printf 'LANG=en_US.UTF-8\n' > /etc/locale.conf

# 运维用户 cyrene（wheel），无密码登录，仅公钥
RUN useradd -m -G wheel -s /bin/bash cyrene \
    && install -d -m 0700 -o cyrene -g cyrene /home/cyrene/.ssh \
    && cp /etc/ssh/authorized_keys/root /home/cyrene/.ssh/authorized_keys \
    && chown cyrene:cyrene /home/cyrene/.ssh/authorized_keys \
    && chmod 0600 /home/cyrene/.ssh/authorized_keys

# ─────────────────────────── initramfs ───────────────────────────
# r8152（USB LAN 网卡）必须在 initrd 里，否则根挂载/网络早期阶段拿不到 LAN。
# 改动 /usr/lib/dracut/dracut.conf.d 后必须重跑这一步。
RUN set -eux; \
    kver=$(ls /usr/lib/modules); \
    DRACUT_NO_XATTR=1 dracut -vf "/usr/lib/modules/${kver}/initramfs.img" "${kver}"

# ─────────────────────────── 结构校验 ───────────────────────────
RUN bootc container lint

LABEL org.opencontainers.image.title="router-bootc" \
      org.opencontainers.image.description="Fedora bootc router (replaces nixos-router)"
