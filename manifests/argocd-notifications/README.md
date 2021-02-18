# Building argocd-notifications for ARM64

## Build binaries

```sh
git clone git@github.com:argoproj-labs/argocd-notifications.git
cd argocd-notifications/
# Checkout release branch
git checkout origin/release-1.0
# Edit arm build in Dockerfile
sed -i '' 's/amd64/arm64/g' Dockerfile
# Build the ARM binary
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags="-w -s" -o ./dist/argocd-notifications-linux-arm64 ./cmd
```

## Build containers with buildx and push

```sh
# Specify container image repo
export IMAGEREPO=mylesagray
# Clean up buildx before first run (sometimes fixes weird bugs)
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
# Create buildx cross-builder based on QEMU
docker buildx create --name  builder
# Initialise buildx
docker buildx inspect --bootstrap
# Build the cross-platform container with the builder and push to repo
docker buildx build --platform linux/amd64,linux/arm64 -t $IMAGEREPO/argocd-notifications:$(shell cat VERSION) --push .
```

### References

* <https://medium.com/nttlabs/buildx-multiarch-2c6c2df00ca2>

## (Optional) Build containers with buildx through K8s

```sh
# Specify container image repo
export IMAGEREPO=mylesagray
# Initialise buildx on K8s cluster (uses current context in ~/.kube/config)
docker buildx create --use --name=buildkit --platform=linux/amd64 --node=buildkit-amd64 --driver=kubernetes --driver-opt="namespace=buildkit,nodeselector=kubernetes.io/arch=amd64,replicas=3"
# Add ARM64 build support
docker buildx create --append --name=buildkit --platform=linux/arm64 --node=buildkit-arm64 --driver=kubernetes --driver-opt="namespace=buildkit,nodeselector=kubernetes.io/arch=arm64,replicas=3"
# Create buildx pods on K8s cluster
docker buildx inspect --bootstrap
# Run the build (note: this only builds for arm64 in this example)
docker buildx build --platform linux/arm64 -t $IMAGEREPO/argocd-notifications:$(shell cat VERSION) --push .
```

### References

* <https://medium.com/nttlabs/buildx-kubernetes-ad0fe59b0c64>
* <https://github.com/docker/buildx/issues/516>
