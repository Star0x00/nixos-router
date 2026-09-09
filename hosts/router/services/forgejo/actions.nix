# Forgejo Actions runner(经 podman 跑 job, 不引入 docker)。启用步骤见本目录 README.md。
{ pkgs, ... }:
let
  net = import ../../net.nix;
in
{
  # runner 走 Docker 客户端默认 socket 连 podman(docker-compat API)
  virtualisation.podman.dockerSocket.enable = true;

  services.forgejo-runner = {
    package = pkgs.forgejo-runner;
    instances.forgejo = {
      enable = false;                 # 填好 uuid + 写好 token 后再置 true
      settings = {
        # 标签名 = workflow 的 runs-on
        runner.labels = [
          "ubuntu-latest:docker://catthehacker/ubuntu:act-latest"
          # "self-hosted:host"        # 直接在主机跑, 适合 nix 任务
        ];
        # 新版 runner 用 uuid + token 一对连接(旧 Registration Token 已废弃)
        server.connections.forgejo = {
          url = "http://${net.lanIp}:3000/";
          uuid = "REPLACE_WITH_UUID_FROM_UI";
        };
      };
      # token 从文件经 systemd LoadCredential 读, 不明文进 nix store
      secrets.server.connections.forgejo.token_url = "/etc/forgejo-runner/token";
    };
  };
}