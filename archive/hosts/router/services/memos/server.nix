# Memos 轻量自托管备忘录。访问 http://10.10.10.1:5230, 数据在 /var/lib/memos。
# 首次注册的账号即管理员; 要点见本目录 README.md。
{ ... }:
let
  net = import ../../net.nix;
  dataDir = "/var/lib/memos";
  port = 5230;
in
{
  services.memos = {
    enable = true;
    dataDir = dataDir;

    # 环境变量即 memos 运行参数(CLI flag 转成 MEMOS_ 前缀)。
    settings = {
      MEMOS_ADDR = net.lanIp;         # 只绑内网(WAN 侧 nftables 本来就 drop)
      MEMOS_PORT = toString port;
      MEMOS_DRIVER = "sqlite";
      MEMOS_DATA = dataDir;
      # MEMOS_INSTANCE_URL 留空 = 私有模式(默认), 不对外/不开公开 API
    };

    openFirewall = false;             # 防火墙统一由 network.nix 的 nftables 管
  };

  # 绑定内网 IP: 等 LAN 网卡就绪再起(同 sshd/kea), 否则 EADDRNOTAVAIL。
  systemd.services.memos = {
    after = [ net.lanDevice "network-online.target" ];
    bindsTo = [ net.lanDevice ];
    wants = [ "network-online.target" ];
  };
}