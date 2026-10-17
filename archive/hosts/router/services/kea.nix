# Kea DHCP4: 只做 DHCP, 不处理 DNS(替代旧 AdGuardHome 的 DHCP 职责)。
# DNS 由 dae 用 eBPF 拦截处理, 广告拦截也在 dae 的 DNS 路由中完成。
_:

let
  net = import ../net.nix;
in
{
  services.kea.dhcp4 = {
    enable = true;

    settings = {
      interfaces-config.interfaces = [ net.lanInterface ];

      # 租约数据库: memfile(内存 + CSV 文件持久化)
      lease-database = {
        type = "memfile";
        persist = true;
        name = "/var/lib/kea/dhcp4.leases";
      };

      # DHCP 计时器(秒)
      renew-timer = 1000;    # T1: 客户端续约
      rebind-timer = 2000;   # T2: rebind
      valid-lifetime = 4000; # 租期

      subnet4 = [
        {
          id = 1;
          subnet = "10.10.10.0/24";
          pools = [ { pool = "10.10.10.2 - 10.10.10.100"; } ];
          option-data = [
            { name = "routers"; data = net.lanIp; }
            # DNS 指向路由器 IP 即可 —— dae 会 eBPF 拦截 DNS, 无需本机监听 53
            { name = "domain-name-servers"; data = net.lanIp; }
            { name = "subnet-mask"; data = "255.255.255.0"; }
            { name = "broadcast-address"; data = "10.10.10.255"; }
          ];
        }
      ];

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

  # 等 LAN 网卡就绪再启动
  # 注意: NixOS kea 模块生成的服务单元是 kea-dhcp4-server.service,
  # 写成 kea-dhcp4 会凭空造出一个无 ExecStart 的坏单元(bad-setting)。
  systemd.services.kea-dhcp4-server = {
    after = [ net.lanDevice "network-online.target" ];
    wants = [ net.lanDevice "network-online.target" ];
  };
}