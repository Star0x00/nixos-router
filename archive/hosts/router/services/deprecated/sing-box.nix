# sing-box: SOCKS5 proxy providers for dae. —— 已废弃, 不再导入。
#
# dae 现在直接使用 Sub-Store 订阅作为节点池, 不再需要 sing-box 这一层。
# 保留仅供参考; 要重新启用需把本文件加回 services/default.nix 的 imports,
# 并把 dae 配置改回走 socks5://127.0.0.1:2080 / 2081。
#
# dae performs eBPF-based transparent proxying and traffic splitting;
# sing-box only handles outbound proxy connections.
#
# 两份实例(进程名同为 `sing-box`,dae 用一条 pname(sing-box) -> must_direct 同时豁免):
#   sing-box-a  socks 127.0.0.1:2080  → 本机流量(dae local_flow / fallback)
#   sing-box-b  socks 127.0.0.1:2081  → LAN 设备流量(dae lan_flow)
# 订阅、配置目录、监听端口、clash_api 端口都必须各自分开,进程名保持同名。
{ lib, pkgs, ... }:

let
  singboxGid = 999;
  singboxBin = lib.getExe pkgs.sing-box;

  # 各实例差异项。nodeUrl = SubStore 的 collection 下载地址。
  # 换订阅时: 改这里 + 跑 `just gen-bases` 更新仓库里的 base 模板。
  genScript = ../../assets/gen-singbox-base.mjs;
  instances = {
    a = {
      # 现用订阅,给本机流量
      nodeUrl = "http://127.0.0.1:3001/qwerhyy123/download/collection/singbox?target=sing-box";
      generate = true;
      baseTemplate = ../../assets/singbox-a-base.json;
    };
    b = {
      # 现用订阅,给 LAN 设备流量。
      # 每日更新时用刚下载的 node.json 重新生成地区组, 即就地重建 base.json,
      # 所以 base.json 是运行时文件, 不再由 environment.etc 建只读软链。
      nodeUrl = "http://10.10.10.1:3001/qwerhyy123/download/jiuxiang?target=sing-box";
      generate = true;
      baseTemplate = ../../assets/singbox-b-base.json;
    };
  };

  mkUnits = name: inst: {
    "sing-box-${name}" = {
      description = "sing-box (${name})";
      after = [
        "network-online.target"
        "kea-dhcp4-server.service"
      ];
      wants = [
        "network-online.target"
        "kea-dhcp4-server.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${singboxBin} run -C /etc/singbox-${name}";
        WorkingDirectory = "/etc/singbox-${name}";
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

    # 每天 7 点(以及开机)从路由器 SubStore 拉取本实例节点配置并重启
    "sing-box-${name}-update" = {
      description = "Update sing-box (${name}) node config from router SubStore";
      after = [
        "network-online.target"
        "podman-sub-store.service"
        "sing-box-${name}.service"
      ];
      wants = [
        "network-online.target"
        "podman-sub-store.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.curl pkgs.coreutils pkgs.systemd ];
      serviceConfig = {
        Type = "oneshot";
        # 先下载到 /run, 成功后才替换 node.json,
        # 避免 SubStore 未就绪时 curl 失败把配置截断成空文件。
        ExecStartPre = "${pkgs.coreutils}/bin/rm -f /run/singbox-${name}.node.json";
        ExecStart = "${pkgs.curl}/bin/curl -s -f -m 30 -o /run/singbox-${name}.node.json '${inst.nodeUrl}'";
        ExecStartPost =
          [
            "${pkgs.coreutils}/bin/install -m 0640 -o singbox -g singbox /run/singbox-${name}.node.json /etc/singbox-${name}/node.json"
          ]
          ++ lib.optionals (inst.generate or false) [
            # 用最新的 node.json 重建 base.json(重写地区组), 模板取自 nix store
            "${pkgs.nodejs}/bin/node ${genScript} /etc/singbox-${name}/node.json ${inst.baseTemplate} /etc/singbox-${name}/base.json"
          ]
          ++ [
            "${pkgs.systemd}/bin/systemctl try-restart sing-box-${name}.service"
          ];
      };
    };
  };

  mkTimer = name: _: {
    "sing-box-${name}-update" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "07:00";
        Persistent = true;
      };
    };
  };
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
      "d /etc/singbox-a 0750 singbox singbox -"
      "d /etc/singbox-b 0750 singbox singbox -"
    ];

    services = lib.mkMerge (lib.mapAttrsToList mkUnits instances);
    timers = lib.mkMerge (lib.mapAttrsToList mkTimer instances);
  };

  environment.systemPackages = [ pkgs.sing-box ];

  # A/B 的 base.json 都由 sing-box-<name>-update 用 gen-singbox-base.mjs
  # 在运行时生成(模板取自 nix store), 所以这里不再用 environment.etc 建软链。
}
