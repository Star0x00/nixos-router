# dae: eBPF-based transparent proxy / traffic splitter.
# Proxied traffic is forwarded to sing-box via local SOCKS5.
_:

let
  daeConfig = builtins.readFile ../assets/dae.dae;
in
{
  services.dae = {
    enable = true;
    config = daeConfig;
  };

  systemd.services.dae = {
    after = [
      "network-online.target"
      "kea-dhcp4-server.service"
      "sing-box-a.service"
      "sing-box-b.service"
    ];
    wants = [
      "network-online.target"
      "kea-dhcp4-server.service"
      "sing-box-a.service"
      "sing-box-b.service"
    ];
    # B 挂了也要让 dae 起来(A/本机流不受影响),所以只 requires a
    requires = [ "sing-box-a.service" ];
  };
}
