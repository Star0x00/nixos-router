# 构建路由器配置
build:
	nix build .#nixosConfigurations.router.config.system.build.toplevel

# 远程部署（需 SSH root@10.10.10.1）
deploy:
	nixos-rebuild switch --flake .#router --target-host root@10.10.10.1 --use-remote-sudo
switch:
	sudo nixos-rebuild switch --flake ~/nixos-router#router

# [已废弃] 重新生成 sing-box A/B 的 base 模板(地区节点组), 需 SubStore 在跑
# URL 即 services/deprecated/sing-box.nix 里 instances.<x>.nodeUrl, 换订阅时两边一起改
# (dae 已改为直接拉 SubStore 的 ?target=V2Ray 订阅, 不再需要这两个 base)
gen-bases: gen-a-base gen-b-base

gen-a-base:
	node hosts/router/assets/gen-singbox-base.mjs 'http://127.0.0.1:3001/qwerhyy123/download/collection/singbox?target=sing-box' hosts/router/assets/singbox-a-base.json

gen-b-base:
	node hosts/router/assets/gen-singbox-base.mjs 'http://10.10.10.1:3001/qwerhyy123/download/jiuxiang?target=sing-box' hosts/router/assets/singbox-b-base.json
