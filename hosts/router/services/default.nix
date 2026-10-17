# Router services: DNS/DHCP, proxy stack, and podman workloads.
{ ... }:

{
  imports = [
    ./kea.nix
    # ./sing-box.nix  # 已废弃: dae 直接用 Sub-Store 订阅, 不再经过 sing-box
    ./dae.nix
    ./sub-store/container.nix
    ./memos/server.nix
    ./forgejo/server.nix
    ./forgejo/actions.nix
    ./openlist/openlist.nix
  ];
}
