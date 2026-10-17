# 构建路由器 bootc 镜像
build tag="dev":
    podman build -t localhost/router-bootc:{{tag}} .

lint tag="dev":
    podman run --rm localhost/router-bootc:{{tag}} bootc container lint

push tag="dev":
    #!/usr/bin/env bash
    set -euo pipefail
    t={{tag}}
    podman tag localhost/router-bootc:$t 10.10.10.1:3000/cyrene/router-bootc:$t
    podman push 10.10.10.1:3000/cyrene/router-bootc:$t

# 装机到指定盘（会清空该盘）
install disk tag="dev":
    podman run --rm --privileged --pid=host --ipc=host \
      -v /var/lib/containers:/var/lib/containers -v /dev:/dev \
      --security-opt label=type:unconfined_t \
      localhost/router-bootc:{{tag}} \
      bootc install to-disk --filesystem btrfs --wipe {{disk}}

# 生成安装 ISO 到 ./output
iso tag="dev":
    mkdir -p output
    podman run --rm --privileged --pid=host --security-opt label=type:unconfined_t \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      -v "$PWD/output:/output" \
      quay.io/centos-bootc/bootc-image-builder:latest \
      --type anaconda-iso --rootfs btrfs \
      localhost/router-bootc:{{tag}}
