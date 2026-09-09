# 构建路由器配置
build:
	nix build .#nixosConfigurations.router.config.system.build.toplevel

# 远程部署（需 SSH root@10.10.10.1）
deploy:
	nixos-rebuild switch --flake .#router --target-host root@10.10.10.1 --use-remote-sudo
switch:
	sudo nixos-rebuild switch --flake ~/nixos-router#router

# 构建本地 CI runner 镜像并载入路由器 podman(不推 registry)
# 换 base 镜像报 hash mismatch 时, 把报错里 “got: sha256-...” 填进 pkgs/ci-runner.nix 的 outputHash 再跑
ci-runner:
	nix build .#ciRunner
	sudo podman load -i result
