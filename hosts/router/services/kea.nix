# Kea DHCP4: 替代 AdGuardHome 的 DHCP 服务器功能。
#
# 只负责 DHCP，不处理 DNS。DNS 由 dae 通过 eBPF 拦截处理，
# 广告拦截也在 dae 的 DNS 路由中完成。
_:

let
  net = import ../net.nix;
in
{
  services.kea = {
    dhcp4 = {
      enable = true;

      settings = {
        # 监听的网络接口
        interfaces-config = {
          interfaces = [ net.lanInterface ];
        };

        # 租约数据库：memfile（内存 + CSV 文件持久化）
        lease-database = {
          type = "memfile";
          persist = true;
          name = "/var/lib/kea/dhcp4.leases";
        };

        # DHCP 计时器（单位：秒）
        renew-timer = 1000; # T1：客户端开始续约
        rebind-timer = 2000; # T2：客户端开始 rebind
        valid-lifetime = 4000; # 地址租期

        # 子网配置
        subnet4 = [
          {
            id = 1;
            subnet = "10.10.10.0/24";
            pools = [
              {
                pool = "10.10.10.2 - 10.10.10.100";
              }
            ];
            # DHCP option：下发给客户端的网络参数
            option-data = [
              {
                # 网关（路由器地址）
                name = "routers";
                data = net.lanIp;
              }
              {
                # DNS 服务器——dae 会通过 eBPF 拦截所有 DNS 流量，
                # 所以客户端指向路由器 IP 即可，无需实际监听 53 端口
                name = "domain-name-servers";
                data = net.lanIp;
              }
              {
                # 子网掩码
                name = "subnet-mask";
                data = "255.255.255.0";
              }
              {
                # 广播地址
                name = "broadcast-address";
                data = "10.10.10.255";
              }
            ];
          }
        ];

        # 日志配置
        loggers = [
          {
            name = "kea-dhcp4";
            output_options = [
              {
                output = "syslog";
                pattern = "%d{%Y.%m.%d %H:%M:%S.%q} %-5p [%c/%i] %m\n";
              }
            ];
            severity = "INFO";
            debuglevel = 0;
          }
        ];
      };
    };
  };

  # Kea 需要在 LAN 接口就绪后才能启动
  systemd.services.kea-dhcp4 = {
    after = [
      net.lanDevice
      "network-online.target"
    ];
    wants = [
      net.lanDevice
      "network-online.target"
    ];
  };
}
