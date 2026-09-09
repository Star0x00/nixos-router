# AdGuard Home —— 已废弃, 不再导入(旧方案)。
# 原为 LAN DNS 拦截 + DHCP, 现已被 kea(DHCP) + dae(DNS)
# 取代; 保留仅供参考。要重新启用需把 services/deprecated
# 加回 services/default.nix 的 imports。
{ pkgs, ... }:

let
  net = import ../../net.nix;

  # dnsmasq-china-list: 中国域名列表 → [domain/]upstream 格式
  chinaListSrc = pkgs.fetchurl {
    url = "https://cdn.jsdelivr.net/gh/felixonmars/dnsmasq-china-list@master/accelerated-domains.china.conf";
    hash = "sha256-O9wJPMnpQyPzvsI6XL9D1/316WRSP91aIQfojX6WMF4=";
  };

  # 中国域名走 UDP 直连(AliDNS + DNSPod); 兜底 1.1.1.1 / 8.8.8.8
  chinaUpstreamFile = pkgs.runCommand "china-upstream.txt" { } ''
    awk -F/ '{printf "[/%s/]https://sm2.doh.pub/dns-query https://dns.alidns.com/dns-query\n", $2}' \
      < ${chinaListSrc} > $out
    echo "https://1.1.1.1/dns-query" >> $out
    echo "https://8.8.8.8/dns-query" >> $out
  '';
in
{
  # 绑 10.10.10.1, 等 LAN 网卡就绪再起
  systemd.services.adguardhome = {
    after = [ net.lanDevice "network-online.target" ];
    wants = [ net.lanDevice "network-online.target" ];
  };

  services.adguardhome = {
    enable = true;

    # 允许在 Web UI 调整(拦截列表/按客户端规则/自定义上游)并持久化;
    # 代价是 UI 改动会覆盖本文件里设的项, 直到下次改本文件再 switch。
    mutableSettings = true;

    openFirewall = false;   # 防火墙在 network.nix 里由 nftables 统一管

    settings = {
      dns = {
        bind_hosts = [ net.lanIp "127.0.0.1" ];
        port = 53;
        upstream_dns = [ "https://1.1.1.1/dns-query" "https://8.8.8.8/dns-query" ];
        upstream_dns_file = "${chinaUpstreamFile}";
        bootstrap_dns = [ "223.5.5.5" "1.1.1.1" ];
        protection_enabled = true;
        filtering = {
          protection_enabled = true;
          filters_update_interval = 24; # hours
          filters = [
            {
              enabled = true;
              id = 1;
              url = "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt";
              name = "AdGuard DNS filter";
            }
            {
              enabled = true;
              id = 2;
              url = "https://anti-ad.net/easylist.txt";
              name = "Anti-AD";
            }
          ];
        };
        cache_size = 4194304; # 4 MiB
      };

      # DHCP(已被 kea 取代, 保留示例)
      dhcp = {
        enabled = true;
        interface_name = net.lanInterface;
        dhcpv4 = {
          gateway_ip = net.lanIp;
          subnet_mask = "255.255.255.0";
          range_start = "10.10.10.2";
          range_end = "10.10.10.100";
          lease_duration = 4000;
        };
        dhcpv6.range_start = "";   # 显式关 v6, 避免 "neither dhcpv4 nor dhcpv6" 致命错误
      };

      web = { bind_host = net.lanIp; port = 3000; };

      users = [ ];              # 无鉴权 —— 仅 LAN, WAN 入站被 nftables drop
      querylog_enabled = true;
      querylog_interval = 90;   # 查询日志保留天数
    };
  };
}