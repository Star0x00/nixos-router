# Router machine profile.
# Aggregates per-feature modules; shared constants live in ./net.nix.
{ inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.daeuniverse.nixosModules.dae

    ./boot.nix
    ./base.nix
    ./network.nix
    ./services
  ];

  system.stateVersion = "26.05";
}
