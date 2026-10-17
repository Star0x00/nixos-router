# dae: eBPF-based transparent proxy / traffic splitter.
#
# dae 直接使用 Sub-Store 的订阅作为节点池(不再经过 sing-box)。
# 配置拆成入口 + config.d/ 分片, 入口用 include 引入。
# 详见: https://github.com/daeuniverse/dae/blob/main/example.dae (include 部分)
{
  lib,
  pkgs,
  config,
  ...
}:

let
  # 仓库里的配置源文件
  srcDir = ../assets/dae;

  # 分片按文件名前缀排序加载; 每个分片只放一个 section。
  fragments = [
    "10-global"
    "20-subscription"
    "30-dns"
    "40-group"
    "50-routing"
  ];

  entryConfig = builtins.readFile "${srcDir}/config.dae";

  # dae 启动时才去 Sub-Store 拉订阅; 等它的 HTTP 端口就绪(最多 60s),
  # 超时就照常启动(免得 Sub-Store 挂了连 dae 都起不来)。
  waitForSubStore = pkgs.writeShellScript "dae-wait-sub-store" ''
    for _ in $(seq 1 30); do
      if ${lib.getExe pkgs.curl} -s -m 2 -o /dev/null \
        'http://127.0.0.1:3001/qwerhyy123/api/utils/env'; then
        exit 0
      fi
      sleep 2
    done
    echo "Sub-Store 未在 60s 内就绪, 仍然启动 dae" >&2
    exit 0
  '';
in
{
  services.dae = {
    enable = true;
    # 用 nixpkgs 的 dae(v2.0.0)。它是标准 nixpkgs 包, 有 cache.nixos.org
    # 二进制缓存, 不用像 flake 的 dae-unstable 那样本地从源码编译。
    package = pkgs.dae;
    config = entryConfig;
  };

  # 分片放到 /etc/dae/config.d/, 与模块写入的 /etc/dae/config.dae 同目录,
  # 这样 include 的相对路径才能通过 dae 的「必须在入口目录之下」检查。
  #
  # mode 必须是 0400/0600/0640: dae 会拒绝任何 group/other 可读写执行
  # 的配置文件(见 config/config_merger.go 的权限检查)。
  environment.etc = builtins.listToAttrs (
    map (name: {
      name = "dae/config.d/${name}.dae";
      value = {
        text = builtins.readFile "${srcDir}/config.d/${name}.dae";
        mode = "0400";
      };
    }) fragments
  );

  systemd.services.dae = {
    # 订阅来自本机 Sub-Store, 尽量等它起来再拉节点。
    after = [
      "network-online.target"
      "kea-dhcp4-server.service"
      "podman-sub-store.service"
    ];
    wants = [
      "network-online.target"
      "podman-sub-store.service"
    ];
    # 模块已把 `dae validate` 放进 ExecStartPre, 这里追加一个等待脚本。
    serviceConfig.ExecStartPre = lib.mkAfter [ waitForSubStore ];
  };

  # ── 定期刷新订阅 ──
  # dae 只在启动 / `dae reload` 时重新拉取 subscription, 自身没有定时刷新
  # (源码里 ResolveSubscription 只被 BuildControlPlane 调用)。
  # 用 timer 定期跑 `dae reload`: 它重新拉订阅并平滑换节点, 不断已有连接;
  # 比 `systemctl restart dae` 好 —— 后者会重建整个 eBPF 数据面。
  systemd.services.dae-reload = {
    description = "dae 订阅刷新(平滑 reload)";
    after = [ "dae.service" ];
    requires = [ "dae.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.services.dae.package}/bin/dae reload";
    };
  };

  systemd.timers.dae-reload = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # 每 6 小时刷新一次(00:30 / 06:30 / 12:30 / 18:30)
      OnCalendar = "*-*-* 00/6:30:00";
      Persistent = true;            # 关机错过的, 下次开机补跑一次
      RandomizedDelaySec = "5min";  # 错开, 避免整点扎堆
    };
  };
}
