# Sub-Store subscription manager, running under rootless podman.
# Image: xream/sub-store (http-meta tag, 含 HTTP-META 功能)
#
# Sub-Store 的自定义项是「环境变量」, 在 NixOS 的 oci-containers 里
# 用 `environment` 字段设置 (对应 docker run 的 `-e`),
# 而 podman/docker 本身的命令行参数 (如 --network / --restart / --tz)
# 才放在 `extraOptions` 里。
_:

let
  # 持久化数据放在宿主机, 容器挂载这个目录
  dataDir = "/var/lib/sub-store";
  port = 3001;
in
{
  # ---------- podman ----------
  virtualisation = {
    podman = {
      enable = true;
      # `dockerCompat` 让 `docker` 命令指向 podman, 并复用 docker socket 路径
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    # ---------- 容器 ----------
    oci-containers = {
      backend = "podman";
      containers.sub-store = {
        image = "docker.io/xream/sub-store:http-meta";
        autoStart = true;
        ports = [ "${toString port}:3001" ];
        volumes = [ "${dataDir}:/opt/app/data" ];

        # Sub-Store 自定义环境变量 (-e)
        environment = {
          # 后端前缀路径, 拼在访问 URL 里起防扫作用.
          # 访问地址: http://10.10.10.1:3001/<backendPath>/api/utils/env
          SUB_STORE_FRONTEND_BACKEND_PATH = "/qwerhyy123";
          # 每天 23:55 定时同步订阅/文件到私有 Gist
          SUB_STORE_BACKEND_SYNC_CRON = "55 23 * * *";
          # 默认代理 (如需让 Sub-Store 走代理抓订阅可填):
          # SUB_STORE_BACKEND_DEFAULT_PROXY = "http://127.0.0.1:7890";
          # 推送服务 (Bark / PushPlus / Telegram), 取消注释填自己的 key:
          # SUB_STORE_PUSH_SERVICE = "https://api.day.app/XXXXXXXX/[推送标题]/[推送内容]";
          # 响应头过大时报 Headers Overflow 时调大:
          # SUB_STORE_MAX_HEADER_SIZE = "65536";
          # 自定义 JSON body 限制 (默认 1mb):
          # SUB_STORE_BODY_JSON_LIMIT = "10mb";
          # 定时备份/恢复全量数据到 Gist:
          SUB_STORE_BACKEND_UPLOAD_CRON = "0 4 * * *";
          # SUB_STORE_BACKEND_DOWNLOAD_CRON = "0 5 * * *";
        };

        # podman/docker 运行参数
        extraOptions = [
          "--name=sub-store"
          "--tz=local"
        ];
      };
    };
  };

  # ---------- 数据目录 ----------
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0755 root root -"
  ];

  # 让 podman 服务在 LAN 就绪后再拉起, 避免开机竞态
  systemd.services.podman-sub-store = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
