# Router-bootc

This repository has a container that can become my homelab server in charge of network router and some service. It uses `bootc` and bases on `fedora-bootc`.

## Main Information

| Key        | Value                                                        |
| ---------- | ------------------------------------------------------------ |
| Hostname   | router                                                       |
| WAN        | `eno1`,DHCP                                                  |
| LAN        | `enp0s20f0u1` (USB RTL8153), `10.10.10.1/24`                 |
| Root SSH   | see rootfs/etc/ssh/authorized_keys/root(./rootfs/etc/ssh/authorized_keys/root) |
| Base image | `quay.io/fedora/fedora-bootc:44`                             |
| Service    | `sub-store` `singbox` `dae`                                  |

## Layout

```text
├── .github
│   └── workflows
│       └── build.yml                              # CI: build + lint + push to GHCR
├── rootfs                                         # copied verbatim onto /
│   ├── etc
│   │   ├── containers
│   │   │   └── registries.conf.d                  # container registries
│   │   │       └── 10-router.conf                 # local registries
│   │   ├── dae                                    # dae config
│   │   │   ├── config.d
│   │   │   │   ├── 10-global.dae
│   │   │   │   ├── 20-node.dae
│   │   │   │   ├── 30-dns.dae
│   │   │   │   ├── 40-group.dae
│   │   │   │   └── 50-routing.dae
│   │   │   └── config.dae
│   │   └── ssh
│   │       ├── authorized_keys                    # ssh key
│   │       │   └── root
│   │       └── sshd_config.d                      # ssh config
│   │           └── 10-router.conf
│   └── usr
│       ├── lib
│       │   ├── bootc
│       │   │   └── kargs.d                        # kernel args
│       │   │       └── 50-selinux.toml            # ban selinux
│       │   ├── dracut
│       │   │   └── dracut.conf.d
│       │   │       └── 50-router-modules.conf     # pull r8152 into the initrd early
│       │   ├── modprobe.d
│       │   │   └── 99-router.conf                 # ban r8153_ecm
│       │   ├── sysctl.d
│       │   │   └── 90-router.conf                 # enable forwarding
│       │   ├── systemd
│       │   │   ├── network                        # systemd-networkd
│       │   │   │   ├── 10-lan.network             # lan config
│       │   │   │   └── 10-wan.network             # wan config
│       │   │   └── system                         # systemd service units
│       │   │       ├── dae.service.d
│       │   │       │   └── 10-router.conf         # dae geoip/geosite
│       │   │       ├── nftables.service.d
│       │   │       │   └── 10-router-conf.conf    # refresh and enable nft rules
│       │   │       ├── sshd.service.d
│       │   │       │   └── 10-router-lan.conf     # ssh bind to lan
│       │   │       ├── llama-model-fetch.service  # pull Hy-MT2 GGUF
│       │   │       └── sing-box.service           # sing-box service
│       │   ├── sysusers.d                         # create user
│       │   │   └── sing-box.conf                  # sing-box user and group
│       │   ├── tmpfiles.d                         # systemd-tmpfiles
│       │   │   └── router.conf                    # create dir
│       │   └── udev                               # device
│       │       └── rules.d                        # rules
│       │           └── 90-usb-nic-power.rules     # keep usb work
│       └── share
│           ├── containers                         # containers
│           │   └── systemd                        # podman quadlets
│           │       ├── llama-server.container     # llama translate service
│           │       └── sub-store.container        # sub-store
│           └── router                             # scripts
│               ├── dae
│               │   └── seed-assets.sh             # cp dae geoip/geosite to /var
│               ├── llama
│               │   └── fetch-model.sh             # download models
│               ├── nftables
│               │   └── nftables.conf              # nftables rules
│               └── sing-box
│                   ├── base.json                  # sing-box config template
│                   └── update.py                  # node update script
├── .gitignore
├── Containerfile                                  # main
├── justfile                                       # just command
├── pyrightconfig.json
├── README.md
└── ruff.toml
```

## Service

| Service      | Informations              |
| ------------ | ------------------------- |
| sub-store    | `10.10.10.1:3001/qwerhyy` |
| llama-server | `10.10.10.1:8080`         |
