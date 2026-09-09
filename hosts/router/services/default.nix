# Router services: DNS/DHCP, proxy stack, and podman workloads.
{ ... }:

{
  imports = [
    ./kea.nix
    ./sing-box.nix
    ./dae.nix
    ./sub-store/container.nix
    ./memos/server.nix
    ./forgejo/server.nix
    ./forgejo/actions.nix
  ];
}
