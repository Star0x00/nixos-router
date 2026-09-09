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
      enable = true;                 # 填好 uuid + 写好 token 后再置 true
      settings = {
        # 标签名 = workflow 的 runs-on
        runner.labels = [
          # 自建本地镜像(ubuntu 24.04 + node/git/kaniko/skopeo), 定义见 pkgs/ci-runner.nix。
          # podman load 会把镜像名规范为 localhost/ci-runner, 这里必须带 localhost/ 前缀才能命中本地镜像。
          # 改镜像后: just ci-runner(构建 + podman load), 并同步这里的 tag。
          "ubuntu-latest:docker://localhost/ci-runner:24.04-3"
          # "nix:host"                  # 直接在主机跑 nix, 无需镜像
        ];
        # 新版 runner 用 uuid + token 一对连接(旧 Registration Token 已废弃)
        server.connections.forgejo = {
          url = "http://${net.lanIp}:3000/";
          uuid = "fefa298a-e162-4ebb-9e2b-9c58c4d147e5";
        };
      };
      # token 从文件经 systemd LoadCredential 读, 不明文进 nix store
      secrets.server.connections.forgejo.token_url = "/etc/forgejo-runner/token";
    };
  };
}
