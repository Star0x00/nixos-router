# Base system: hostname, locale, users, packages, ssh, nix settings.
{
  pkgs,
  ...
}:

let
  net = import ./net.nix;
in
{
  networking.hostName = "nixos-router";
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "en_US.UTF-8";

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  users.users.${net.username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      tree
      neovim
      helix
      fastfetch
      nixd
      eza
    ];
  };

  users.users.root.openssh.authorizedKeys.keys = [ net.sshAuthorizedKey ];

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    nixd
    nixfmt
    usbutils
    pciutils
    pi-coding-agent
    nodejs-slim
    nodejs-slim.npm
    fastfetch
  ];

  services.openssh = {
    enable = true;
    listenAddresses = [
      {
        addr = net.lanIp;
        port = 22;
      }
    ];
    settings.PermitRootLogin = "prohibit-password";
  };

  systemd.services.sshd = {
    after = [
      net.lanDevice
      "network-online.target"
    ];
    bindsTo = [ net.lanDevice ];
    wants = [ "network-online.target" ];
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "pipe-operators"
    ];
    substituters = [
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
    ];
  };
  nixpkgs.config.allowUnfree = true;
}
