# Sub-Store 订阅管理容器(podman)。访问 http://10.10.10.1:3001, 数据在 /var/lib/sub-store。
# 全机用的 podman 运行时也在这里启用。要点见本目录 README.md。
{ ... }:
let
  dataDir = "/var/lib/sub-store";
  port = 3001;
in
{
  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;                  # docker 命令 → podman
      defaultNetwork.settings.dns_enabled = true;
    };

    oci-containers = {
      backend = "podman";
      containers.sub-store = {
        image = "docker.io/xream/sub-store:http-meta";
        autoStart = true;
        ports = [ "${toString port}:3001" ];
        volumes = [ "${dataDir}:/opt/app/data" ];

        # Sub-Store 自定义项用环境变量(对应 docker run -e); 可选值见 README.md
        environment = {
          SUB_STORE_FRONTEND_BACKEND_PATH = "/qwerhyy123";  # 后端前缀, 防扫
          SUB_STORE_BACKEND_SYNC_CRON = "55 23 * * *";      # 定时同步到私有 Gist
          SUB_STORE_BACKEND_UPLOAD_CRON = "0 4 * * *";      # 全量备份到 Gist
        };

        extraOptions = [ "--name=sub-store" "--tz=local" ];
      };
    };
  };

  systemd.tmpfiles.rules = [ "d ${dataDir} 0755 root root -" ];

  # podman 容器在 LAN 就绪后再拉起, 避免开机竞态
  systemd.services.podman-sub-store = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}