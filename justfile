# 构建路由器 bootc 镜像（CI 会在 GitHub Actions 上做同样的事）
build tag="dev":
    podman build -t localhost/router-bootc:{{tag}} .
