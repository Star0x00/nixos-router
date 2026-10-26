# fedora-bootc-router

Custom Fedora bootc OCI image replacing the previous NixOS router.
The old NixOS configuration is kept untouched under `archive/`.

## Target host (unchanged from the NixOS setup)

| Item | Value |
|---|---|
| WAN | `eno1`, DHCP |
| LAN | `enp0s20f0u1` (USB RTL8153), `10.10.10.1/24` |
| Hostname | `router` |
| Root SSH | see `rootfs/etc/ssh/authorized_keys/root` |
| Base image | derived from `quay.io/fedora/fedora-bootc:44` |

## Layout

```
Containerfile               # skeleton image (stage 2)
.github/workflows/build.yml # CI: build + lint + push to GHCR
rootfs/                     # copied verbatim onto / (static config prefers /usr)
  etc/dae/                  # dae entry config + config.d fragments (0640)
  etc/containers/           # registries.conf.d (insecure LAN registry)
  usr/share/containers/systemd/  # quadlet units (sub-store, llama-server)
  usr/share/router/dae/     # dae asset seeding script
  usr/share/router/sing-box/# sing-box: base.json, gen-singbox-base.mjs, update.sh
  usr/share/router/llama/   # model fetch script
  usr/share/router/nftables/# nftables.conf
  usr/lib/systemd/system/   # unit drop-ins, sing-box update service/timer
  usr/lib/sysusers.d/       # sing-box system user
archive/                    # previous NixOS repo (reference only, not built)
```

## Proxy chain

```
LAN/host traffic -> dae (eBPF, direct vs proxy)
                       |
                       +-- proxy --> socks5://127.0.0.1:2080 (sing-box)
                                        |
                                        +-- 🚀 节点选择 (selector, default 🚀 Cloudflare)
                                              +-- 🚀 Cloudflare  urltest, cp.cloudflare.com
                                              +-- ♻️ 自动选择   urltest, gstatic
                                              +-- <每个节点>
```

dae decides direct vs proxy (geosite/geoip rules). sing-box holds the whole
node pool from Sub-Store, picks the lowest-latency node on its own, and has no
routing rules of its own (`route.final` = its single selector group). The
groups only decide which node is used and can be switched from the sing-box
dashboard on `http://10.10.10.1:9090`.

- `sing-box-update.service` (boot, plus the `sing-box-update.timer` at 07:00)
  downloads the subscription, runs `gen-singbox-base.mjs` to rewrite
  `outbounds`, validates with `sing-box check`, and only then swaps
  `/etc/sing-box/config.json` and restarts sing-box if it changed.
- The NixOS-era A/B split (socks5 2080 local + 2081 LAN) and the dae-side
  Google/Cloudflare/Japan/lxy groups are gone: one instance, one proxy group.

## Stages

- **Stage 1** Repo reshuffle: all NixOS config moved into `archive/`. Done.
- **Stage 2** Skeleton image: FROM fedora-bootc:44 + base packages + static config
  (networkd/nftables/sshd/sysctl/modprobe/udev/initramfs), passes `bootc container lint`.
- **Stage 3a** dae (eBPF transparent proxy) + sing-box as its SOCKS5 outbound
  (node pool/urltest) + Sub-Store (quadlet container).
- **Stage 3b** LAN DHCP server via systemd-networkd (`DHCPServer=yes`), so kea is
  not needed. Lease DB persists in `/var/lib/systemd/network`.
- **Stage 3c+** Remaining services one at a time: other containers, code hosting (forgejo).

## Accounts

No user account and no password are baked into the image.

**Root login is SSH-key-only.** The key lives in
`rootfs/etc/ssh/authorized_keys/root`; `/etc/ssh/sshd_config.d/10-router.conf`
adds that path to `AuthorizedKeysFile`, because Fedora's default only looks at
`~/.ssh/authorized_keys`.

```sh
ssh root@10.10.10.1          # key from that file
passwd root                  # optional: needed for console/TTY login
```

Extra accounts are not created by the image. Add them manually once, e.g.
`useradd -m -G wheel -s /bin/bash cyrene` plus `passwd cyrene`.

Without `passwd root`, the physical console has no way in (root is locked, no
key path applies to a TTY). Set it once over SSH if you want a console fallback.

Accounts live in `/etc/passwd` and `/var/home` (both writable and upgrade-safe),
so they persist across `bootc upgrade`. To bake one in anyway, derive an image
with `systemd-sysusers` and `/usr/lib/sysusers.d/`.

## Building

Locally:

```sh
just build            # podman build -t localhost/router-bootc:dev .
```

CI (GitHub Actions, `.github/workflows/build.yml`):

- push to `main` -> build + `bootc container lint` + push `ghcr.io/<owner>/router-bootc:latest`
  and `:sha-<12 chars>` (reference is lowercased automatically)
- pull request -> build + lint only, no push
- weekly rebuild on Monday 03:00 UTC to track `fedora-bootc:44`
- changes under `archive/**` and `*.md` do not trigger a build

## Status

Stage 1 done. Stage 2 skeleton config is written but **not yet build-verified**.

## Notes

- Static config lives in `/usr`; only machine-local state belongs in `/etc`
  (bootc does a 3-way merge for `/etc` on upgrades). The generated
  `/etc/sing-box/{node,config}.json` is machine-local by design.
- dae rejects config files that are group-writable or readable by others; the
  Containerfile chmods `/etc/dae/**.dae` to `0640` (the repo files are `0644`).
- `gen-singbox-base.mjs` can be run by hand:
  `node rootfs/usr/share/router/sing-box/gen-singbox-base.mjs <url|node.json> \`
  `rootfs/usr/share/router/sing-box/base.json /tmp/config.json`
- `sing-box/update.sh` pulls the subscription from `http://10.10.10.1:3001/...`
  (the Sub-Store container's published port) and restarts only sing-box; dae is
  untouched because its single node never changes.
- The initramfs is generated at build time; rerun `dracut` after touching its config.
- Fedora defaults to NetworkManager/firewalld here; both are masked in favour of
  systemd-networkd + nftables.
