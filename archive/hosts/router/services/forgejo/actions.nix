# Forgejo Actions runner(host 模式: job 直接在路由器上执行, 直接用宿主 podman build/push)。
# 不再用 job 容器镜像; 工作链由模块的 hostPackages 提供(见下)。启用步骤见本目录 README.md。
{ pkgs, lib, ... }:
let
  net = import ../../net.nix;
in
{
  # podman push 到 http://10.10.10.1:3000 需放行 insecure(宿主 rootful podman 直接用这份 registries.conf)
  virtualisation.containers.registries.settings = {
    registry = [
      { location = "docker.io"; }
      { location = "quay.io"; }
      { location = "10.10.10.1:3000"; insecure = true; }
    ];
  };

  services.forgejo-runner = {
    package = pkgs.forgejo-runner;
    instances.forgejo = {
      enable = true;                 # 填好 uuid + 写好 token 后再置 true
      settings = {
        # label 名 = workflow 的 runs-on; `:host` 表示 job 直接在宿主执行。
        # 宿主网络即本机进程 → dae 域名级分流/代理全生效(无需额外挂 socket)。
        runner.labels = [
          "nixos:host"
        ];
        # 新版 runner 用 uuid + token 一对连接(旧 Registration Token 已废弃)
        server.connections.forgejo = {
          url = "http://${net.lanIp}:3000/";
          uuid = "fefa298a-e162-4ebb-9e2b-9c58c4d147e5";
        };
      };
      # token 从文件经 systemd LoadCredential 读, 不明文进 nix store
      secrets.server.connections.forgejo.token_url = "/etc/forgejo-runner/token";

      # host 模式 job 的 PATH = 这里 + gitMinimal。
      # workflow 里直接 `podman build` / `podman push` / `skopeo` / `git` / node(JS action) 等。
      hostPackages = with pkgs; [
        podman            # 宿主 rootful podman(buildah 构建: 无 BuildKit/嵌套 overlay 问题, 产物与缓存都在宿主)
        git
        jq
        openssh
        skopeo
        bash
        coreutils
        curl
        wget
        gawk
        gnused
        nodejs            # actions/checkout 等 JS action 需要
      ];
    };
  };

  # host 模式 job 要以 root 操作宿主 podman, 覆盖模块给 runner 服务的 DynamicUser。
  # ⚠️ 等价于任意 workflow 都能 root 操作整台路由器, 只对可信仓库开 host label。
  systemd.services.forgejo-runner-forgejo.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "root";
    Group = "root";
  };
}
