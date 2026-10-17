# Build the router bootc image (CI does the same on GitHub Actions)
build tag="dev":
    podman build -t localhost/router-bootc:{{tag}} .
