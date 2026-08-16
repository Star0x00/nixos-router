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
      "kea-dhcp4.service"
      "sing-box.service"
    ];
    wants = [
      "network-online.target"
      "kea-dhcp4.service"
      "sing-box.service"
    ];
    requires = [ "sing-box.service" ];
  };
}
