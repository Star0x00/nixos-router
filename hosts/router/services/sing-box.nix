# sing-box: SOCKS5 proxy provider for dae.
# dae performs eBPF-based transparent proxying and traffic splitting;
# sing-box only handles outbound proxy connections.
{ lib, pkgs, ... }:

let
  configDir = "/etc/singbox";
  singboxGid = 999;
in
{
  users.groups.singbox = {
    name = "singbox";
    gid = singboxGid;
  };

  users.users.singbox = {
    name = "singbox";
    uid = singboxGid;
    group = "singbox";
    isSystemUser = true;
  };

  systemd = {
    tmpfiles.rules = [
      "d ${configDir} 0750 singbox singbox -"
    ];

    services = {
      sing-box = {
        description = "sing-box";
        after = [
          "network-online.target"
          "kea-dhcp4.service"
        ];
        wants = [
          "network-online.target"
          "kea-dhcp4.service"
        ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${lib.getExe pkgs.sing-box} run -C ${configDir}";
          WorkingDirectory = configDir;
          User = "singbox";
          Group = "singbox";
          Restart = "on-failure";
          RestartSec = 5;
          AmbientCapabilities = [
            "CAP_NET_ADMIN"
            "CAP_NET_BIND_SERVICE"
          ];
          CapabilityBoundingSet = [
            "CAP_NET_ADMIN"
            "CAP_NET_BIND_SERVICE"
          ];
        };
      };

      # 每天 7 点从路由器 SubStore 拉取节点配置并重启 sing-box
      sing-box-update = {
        description = "Update sing-box node config from router SubStore";
        after = [
          "network-online.target"
          "sing-box.service"
        ];
        wants = [ "network-online.target" ];
        path = [ pkgs.curl ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.curl}/bin/curl -s -f -m 30 -o /etc/singbox/node.json 'http://127.0.0.1:3001/qwerhyy123/download/collection/singbox?target=sing-box'";
          ExecStartPost = "${pkgs.systemd}/bin/systemctl try-restart sing-box.service";
        };
      };
    };

    timers.sing-box-update = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "07:00";
        Persistent = true;
      };
    };
  };

  environment.systemPackages = [ pkgs.sing-box ];
  environment.etc."/singbox/base.json" = {
    source = ../assets/singbox-base.json;
  };
}
