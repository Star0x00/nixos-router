# AdGuard Home: LAN DNS sinkhole + DHCP server.
#
# Bind hosts are restricted to the LAN address. The nftables filter table
# in network.nix drops all inbound WAN, so this is defense-in-depth
# rather than load-bearing — but it also keeps DNS off the WAN socket
# entirely.
{ pkgs, ... }:

let
  net = import ../net.nix;

  # dnsmasq-china-list: 中国域名列表，用于 AGH 分流
  # 格式转换：server=/domain/upstream → [/domain/]upstream
  chinaListSrc = pkgs.fetchurl {
    url = "https://cdn.jsdelivr.net/gh/felixonmars/dnsmasq-china-list@master/accelerated-domains.china.conf";
    hash = "sha256-O9wJPMnpQyPzvsI6XL9D1/316WRSP91aIQfojX6WMF4=";
  };

  # 中国域名走 UDP 直连（AliDNS + DNSPod，低延迟）
  chinaUpstreamFile = pkgs.runCommand "china-upstream.txt" { } ''
    awk -F/ '{printf "[/%s/]https://sm2.doh.pub/dns-query https://dns.alidns.com/dns-query\n", $2}' \
      < ${chinaListSrc} > $out
    # 兜底：非中国域名走默认上游（避免 AGH 因无默认上游而 fallback 到 Quad9）
    # 注意：每个 upstream 必须单独一行，AGH 不支持在同一行用空格分隔多个默认上游
    echo "https://1.1.1.1/dns-query" >> $out
    echo "https://8.8.8.8/dns-query" >> $out
  '';
in
{
  # DNS server binds to the LAN address (10.10.10.1), so it must wait for
  # the LAN NIC device to be present and for the link to be online. The LAN
  # network is configured with RequiredForOnline = true, so
  # network-online.target is only reached once the link is actually up.
  systemd.services.adguardhome = {
    after = [
      net.lanDevice
      "network-online.target"
    ];
    wants = [
      net.lanDevice
      "network-online.target"
    ];
  };

  services.adguardhome = {
    enable = true;

    # Allow web-UI tweaks (blocklists, per-client rules, custom upstreams)
    # to persist at runtime. Trade-off: any change made in the UI overrides
    # what we set here on the next `nh os switch` unless the user edits
    # this file too. For a home router this is the right default — no one
    # wants to `nh os switch` just to add a blocklist.
    mutableSettings = true;

    # The NixOS firewall (`networking.firewall`) is disabled in network.nix
    # in favour of hand-rolled nftables, so this option would do nothing.
    openFirewall = false;

    settings = {
      # ---- DNS server (LAN-facing) ----
      dns = {
        bind_hosts = [
          net.lanIp
          "127.0.0.1"
        ];
        port = 53;

        # 默认上游（非中国域名）—— 走代理出去
        upstream_dns = [
          "https://1.1.1.1/dns-query"
          "https://8.8.8.8/dns-query"
        ];

        # 中国域名分流文件：中国域名 → dnspod（优先）+ alidns（备用）直连
        upstream_dns_file = "${chinaUpstreamFile}";

        bootstrap_dns = [
          "223.5.5.5"
          "1.1.1.1"
        ];

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

        cache_size = 4194304; # 4 MiB (AGH default)
      };

      # ---- DHCP server ----
      dhcp = {
        enabled = true;
        interface_name = net.lanInterface;

        # DHCPv4 — fields go under dhcpv4, not at the top level, since
        # AGH 0.107.77 (schema_version >= 27).
        dhcpv4 = {
          gateway_ip = net.lanIp;
          subnet_mask = "255.255.255.0";
          range_start = "10.10.10.2";
          range_end = "10.10.10.100";
          lease_duration = 4000; # seconds
        };

        # DHCPv6 — explicitly disabled to avoid the "neither dhcpv4 nor
        # dhcpv6 srv is configured" fatal error.
        dhcpv6 = {
          range_start = "";
        };
      };

      # ---- Web UI (LAN only) ----
      web = {
        bind_host = net.lanIp;
        port = 3000;
      };

      # ---- Misc ----
      users = [ ]; # no auth — LAN-only; the nftables filter blocks WAN
      querylog_enabled = true;
      querylog_interval = 90; # days of query log retention
    };
  };
}
