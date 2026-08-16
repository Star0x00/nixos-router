# NixOS router configuration.
# Deploy with: nh os switch --flake .#router   (or nixos-rebuild)
{
  description = "NixOS router configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    daeuniverse = {
      url = "github:daeuniverse/flake.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, daeuniverse, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.router = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/router ];
      };

      # `nh os switch`, `nixos-rebuild`, etc. read the configured pkgs from
      # this; keep allowUnfree consistent across the flake.
      packages.${system}.default = self.nixosConfigurations.router.config.system.build.toplevel;
    };
}