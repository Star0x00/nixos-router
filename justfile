# 构建路由器配置（本地评估，不部署）
build:
	nix build .#nixosConfigurations.router.config.system.build.toplevel

# 部署到路由器（远程构建，需 SSH root@10.10.10.1）
deploy:
	nixos-rebuild switch --flake .#router --target-host root@10.10.10.1 --use-remote-sudo

# 在路由器本机上部署（SSH 进去后执行）
# nh os switch .