# Forgejo 服务本体 + 独立 btrfs 子卷 + snapper 快照。
# 访问地址与首次部署步骤见本目录 README.md。
{ pkgs, ... }:
let
  net = import ../../net.nix;
  dataDir = "/var/lib/forgejo";
  httpPort = 3000;
in
{
  # 数据独立子卷(物理子卷需一次性创建, 见 README); owner 由模块 tmpfiles 自动改成 forgejo
  fileSystems."${dataDir}" = {
    device = "/dev/disk/by-uuid/f3727793-20bf-4102-b40d-b65dd50d8e19";
    fsType = "btrfs";
    options = [ "subvol=forgejo" "compress=zstd" ];
  };

  services.forgejo = {
    enable = true;
    package = pkgs.forgejo;              # 随 nixos-unstable 走最新版
    database.type = "sqlite3";           # 个人单用户, 一文件即全量备份
    stateDir = dataDir;
    settings = {
      server = {
        PROTOCOL = "http";
        DOMAIN = net.lanIp;
        ROOT_URL = "http://${net.lanIp}:${toString httpPort}/";
        HTTP_ADDR = net.lanIp;           # 只绑内网
        HTTP_PORT = httpPort;
        DISABLE_SSH = false;
        # git-over-SSH 走系统 sshd(forgejo 用户, 端口 22), 未开内置 SSH server。
        # 故 SSH_PORT 保持默认 22(web 上 clone 地址不带端口), 不设 SSH_LISTEN_PORT。
      };
      service.DISABLE_REGISTRATION = true; # 只自己建管理员, 首建时临时置 false
      packages.ENABLED = true;             # 内置 OCI/Docker 镜像仓库
      actions.ENABLED = true;
      actions.DEFAULT_ACTIONS_URL = "github";
    };
  };

  # 绑内网 IP: 等 LAN 网卡就绪再起。数据子卷在 local-fs 阶段先就位, 无需依赖 .mount
  systemd.services.forgejo = {
    after = [ net.lanDevice "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  # snapper 时间线自动快照(快照落在子卷内 .snapshots)
  services.snapper.configs.forgejo = {
    SUBVOLUME = dataDir;
    FSTYPE = "btrfs";
    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    TIMELINE_LIMIT_HOURLY = 6;
    TIMELINE_LIMIT_DAILY = 7;
    TIMELINE_LIMIT_WEEKLY = 4;
    TIMELINE_LIMIT_MONTHLY = 3;
  };
}