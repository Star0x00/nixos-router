# Boot / firmware configuration for the router.
_:

{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      # 限制 /boot 里保留的启动项数量；不设则默认 null = 全部保留，
      # 会撑爆 1GB 的 vfat /boot。每代约 13M kernel + 44M initrd。
      systemd-boot.configurationLimit = 8;
    };
    blacklistedKernelModules = [ "r8153_ecm" ];

    kernel.sysctl."net.ipv4.ip_forward" = 1;
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1d6b", ATTR{idProduct}=="0002", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1d6b", ATTR{idProduct}=="0003", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="8153", ATTR{power/control}="on"
  '';
}
