# Forgejo Actions 的本地 job 镜像: ubuntu 24.04 底 + node/git + daemonless 构建/推送工具。
# 不推 registry: just ci-runner 构建并 podman load 后留本地使用。
# 改 tag 时需同步 hosts/router/services/forgejo/actions.nix 的 labels 里的 ci-runner:${tag}。
{ pkgs, lib }:
let
  tag = "24.04-2";
in
pkgs.dockerTools.buildImage {
  name = "ci-runner";
  inherit tag;

  fromImage = pkgs.dockerTools.pullImage {
    imageName = "ubuntu";
    # ubuntu:24.04 的 linux/amd64 manifest digest(2026-08 更新)
    imageDigest = "sha256:1e0a86e57d247923571b75e0aaf48a1449cf8c543d51fb3e07a4a7d7bfa79316";
    # 换 base 镜像后重新跑一次 nix build, 报错里 “got: sha256-...” 填到这里
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
      kaniko              # 容器内 daemonless 构建(不挂 socket, 不碰 overlay; buildah>=1.44 在容器里会撞嵌套 overlay)
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
}
