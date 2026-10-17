{ ... }: {
  virtualisation.oci-containers.containers = {
    openlist = {
      image = "docker.io/openlistteam/openlist:latest";
      autoStart = true;
      ports = [ "5244:5244" ];
      volumes = [ "/var/lib/openlist:/opt/openlist/data" ];
      user = "1001:1001";
      environment = {
        UMASK = 022;
      };
    };
  };

  systemd.tmpfiles.rules = [ "d /var/lib/openlist 0755 root root -" ];

  # podman 容器在 LAN 就绪后再拉起, 避免开机竞态
  systemd.services.podman-sub-store = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
