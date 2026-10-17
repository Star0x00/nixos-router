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
  etc/dae/                  # dae entry config + config.d fragments (mode 0400)
  etc/containers/           # registries.conf.d (insecure LAN registry)
  usr/share/containers/systemd/  # quadlet units (sub-store)
  usr/share/router/         # nftables conf + helper scripts
  usr/lib/systemd/system/   # unit drop-ins, dae-reload timer
archive/                    # previous NixOS repo (reference only, not built)
```

## Stages

- **Stage 1** Repo reshuffle: all NixOS config moved into `archive/`. Done.
- **Stage 2** Skeleton image: FROM fedora-bootc:44 + base packages + static config
  (networkd/nftables/sshd/sysctl/modprobe/udev/initramfs), passes `bootc container lint`.
- **Stage 3a** dae (eBPF transparent proxy) + Sub-Store (quadlet container).
- **Stage 3b+** Remaining services one at a time: DHCP (kea), other containers,
  code hosting (forgejo).

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
  (bootc does a 3-way merge for `/etc` on upgrades).
- The initramfs is generated at build time; rerun `dracut` after touching its config.
- Fedora defaults to NetworkManager/firewalld here; both are masked in favour of
  systemd-networkd + nftables.
