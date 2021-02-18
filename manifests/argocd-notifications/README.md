# Building argocd-notifications for ARM64

## Build binaries

```sh
git clone git@github.com:argoproj-labs/argocd-notifications.git
cd argocd-notifications/
# Checkout release branch
git checkout origin/release-1.0
# Edit Dockerfile to remove ARCH specific GO builds (will let the container build based on emulation mode)
sed -i '' 's/GOARCH=arm64 //g' Dockerfile
```

## Build containers with buildx (locally) and push

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
docker buildx build --platform linux/amd64,linux/arm64,linux/arm -t $IMAGEREPO/argocd-notifications:$(cat VERSION) --push .
```

### References

* <https://medium.com/nttlabs/buildx-multiarch-2c6c2df00ca2>

## (Optional) Build containers with buildx through K8s with emulation (slow, broadly usable)

```sh
# Specify container image repo
export IMAGEREPO=mylesagray
# Create K8s ns
kubectl create ns buildkit-emu
kubectl create ns qemu-binfmt
# Install buildfmt on all nodes using a DaemonSet
kubectl apply -f manifests/qemu-binfmt/
# Initialise buildx on K8s cluster (uses current context in ~/.kube/config)
docker buildx create --use --name=buildkit-emu --platform=linux/amd64,linux/arm64,linux/arm --driver=kubernetes --driver-opt="namespace=buildkit-emu,replicas=3,image=moby/buildkit:master"
# Create buildx pods on K8s cluster
docker buildx inspect --bootstrap
# Run the build
docker buildx build --platform linux/amd64,linux/arm64,linux/arm -t $IMAGEREPO/argocd-notifications:$(cat VERSION) --push .
```

### References

* <https://medium.com/nttlabs/buildx-kubernetes-ad0fe59b0c64>
* <https://github.com/docker/buildx/issues/516>
* <https://github.com/tektoncd/catalog/tree/master/task/buildkit-daemonless/0.1>
* <https://github.com/moby/buildkit/tree/master/examples/kubernetes>
* <https://github.com/tonistiigi/binfmt>
* <https://github.com/docker/buildx/issues/342#issuecomment-681621872>

## (Optional) Build containers with buildx through K8s on multi-arch cluster (fast, requires arch-specific nodes)

```sh
# Specify container image repo
export IMAGEREPO=mylesagray
# Create K8s ns
kubectl create ns buildkit
# Initialise buildx on K8s cluster (uses current context in ~/.kube/config)
docker buildx create --use --name=buildkit --platform=linux/amd64 --node=buildkit-amd64 --driver=kubernetes --driver-opt="namespace=buildkit,nodeselector=kubernetes.io/arch=amd64,replicas=3"
# Add ARM64 build support can also build ARM v7 and ARM v8
docker buildx create --append --name=buildkit --platform=linux/arm64 --node=buildkit-arm64 --driver=kubernetes --driver-opt="namespace=buildkit,nodeselector=kubernetes.io/arch=arm64,replicas=3"
# Create buildx pods on K8s cluster
docker buildx inspect --bootstrap
# Run the build (note: this only builds for arm* in this example as i only have arm64 nodes)
docker buildx build --platform linux/arm64,linux/arm -t $IMAGEREPO/argocd-notifications:$(cat VERSION) --push .
```

### References

* <https://medium.com/nttlabs/buildx-kubernetes-ad0fe59b0c64>
* <https://github.com/docker/buildx/issues/516>
* <https://github.com/tektoncd/catalog/tree/master/task/buildkit-daemonless/0.1>
* <https://github.com/moby/buildkit/tree/master/examples/kubernetes>
