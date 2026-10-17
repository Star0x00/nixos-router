# Networking: networkd (WAN/LAN + NAT), nftables WAN firewall.
# Transparent proxy is handled by dae via eBPF; no nftables TProxy here.
# DNS is handled by dae via eBPF interception; no nftables DNS redirect needed.
_:

let
  net = import ./net.nix;
in
{
  networking = {
    enableIPv6 = false;
    networkmanager.enable = false;
    useDHCP = false;
    resolvconf.useLocalResolver = false;
    firewall.enable = false;
    # 本机进程 DNS 指向 alidns，dae 的 eBPF 会拦截处理（除 must_direct 进程外）
    nameservers = [ "223.5.5.5" ];
  };

  services.resolved.enable = false;

  systemd = {
    network = {
      enable = true;
      networks = {
        "10-wan" = {
          matchConfig.Name = net.wanInterface;
          networkConfig = {
            Description = "WAN";
            DHCP = "yes";
          };
        };

        "10-lan" = {
          matchConfig.Name = net.lanInterface;
          networkConfig = {
            Description = "LAN (USB NIC)";
            Address = net.lanAddress;
            IPMasquerade = "both";
          };
          linkConfig.RequiredForOnline = true;
        };
      };
    };

    services.systemd-resolved = {
      enable = false;
      unitConfig.ConditionPathExists = "/nonexistent";
    };
  };

  networking.nftables = {
    enable = true;
    tables = {
      # WAN 防火墙：只放行已建立的连接和 LAN 发起的流量
      filter = {
        enable = true;
        name = "filter";
        family = "inet";
        content = ''
          chain input {
            type filter hook input priority 0; policy accept;

            ct state { established, related } accept
            iifname "lo" accept
            iifname ${net.lanInterface} accept
            iifname ${net.wanInterface} drop
          }

          chain forward {
            type filter hook forward priority 0; policy accept;

            ct state { established, related } accept
            iifname ${net.lanInterface} oifname ${net.wanInterface} accept
            iifname ${net.wanInterface} drop
          }
        '';
      };
    };
  };
}
