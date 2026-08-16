# Router services: DNS/DHCP, proxy stack, and podman workloads.
{ ... }:

{
  imports = [
    ./kea.nix
    ./sing-box.nix
    ./dae.nix
    ./sub-store.nix
  ];
}
