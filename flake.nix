{
  description = "NixOS router configuration";

  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    daeuniverse = {
      url = "github:daeuniverse/flake.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # Forgejo Actions 的本地 job 镜像: ubuntu 24.04 底 + node/git + daemonless 构建推送工具。
      # 不推 registry, 构建后 podman load 留本地即可(见 justfile 的 ci-runner)。
      ciRunnerTag = "24.04-1";
      ciRunner = pkgs.dockerTools.buildImage {
        name = "ci-runner";
        tag = ciRunnerTag;
        fromImage = pkgs.dockerTools.pullImage {
          imageName = "ubuntu";
          # ubuntu:24.04 的 linux/amd64 manifest digest(2026-08 更新)
          imageDigest = "sha256:1e0a86e57d247923571b75e0aaf48a1449cf8c543d51fb3e07a4a7d7bfa79316";
          # 第一次 nix build .#ciRunner 会报 hash mismatch, 把报错里 “got: sha256-...” 填到这里
          outputHash = "sha256-HMQIYlUjJ+/bVnp68rNcFXU1D7d+lafDHkqTbnTflTI=";
          outputHashAlgo = "sha256";
          finalImageName = "ubuntu";
          finalImageTag = "24.04";
          os = "linux";
          arch = "amd64";
        };
        fromImageName = "ubuntu";
        fromImageTag = "24.04";
        copyToRoot = pkgs.buildEnv {
          name = "ci-runner-tools";
          paths = with pkgs; [
            bash
            coreutils
            curl
            wget
            gnugrep
            gnused
            git
            nodejs_24           # actions/checkout 等 JS action 需要
            jq
            openssh
            buildah             # daemonless OCI 构建, 无需 docker daemon
            skopeo              # daemonless 镜像推送/拷贝
            pkgs.dockerTools.caCertificates
          ];
        };
        config = {
          Cmd = [ "/bin/bash" ];
          Env = [
            "PATH=/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
          ];
        };
      };
    in
    {
      packages.${system}.ciRunner = ciRunner;
      nixosConfigurations.router = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/router ];
      };
    };
}
