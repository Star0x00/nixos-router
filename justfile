# 构建路由器配置
build:
	nix build .#nixosConfigurations.router.config.system.build.toplevel

# 远程部署（需 SSH root@10.10.10.1）
deploy:
	nixos-rebuild switch --flake .#router --target-host root@10.10.10.1 --use-remote-sudo
switch:
	sudo nixos-rebuild switch --flake ~/nixos-router#router
