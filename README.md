# K8s cluster bootstrap and app install

## Bitnami Sealed Secrets

### Install Sealed Secrets

```sh
helm upgrade --install sealed-secrets -n kube-system ./manifests/sealed-secrets -f manifests/sealed-secrets/values.yaml
```

### Seal secrets

```sh
kubeseal --format=yaml < ~/Desktop/docker-creds.yaml > resources/secrets/docker-creds-sealed.yaml
kubeseal --format=yaml < ~/Desktop/argocd-secret.yaml > resources/secrets/argocd-sealed-secret.yaml
kubeseal --format=yaml < ~/Desktop/argocd-github-secret.yaml > resources/secrets/argocd-github-sealed-secret.yaml
kubeseal --format=yaml < ~/Desktop/argocd-rak8s-secret.yaml > resources/secrets/argocd-rak8s-sealed-secret.yaml
```

### Backup seal key

```sh
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > ~/Desktop/sealed-secrets-master.key
```

## Restore Bitnami SS from backup (if bad things happened)

```sh
helm upgrade --install sealed-secrets -n kube-system ./manifests/sealed-secrets -f manifests/sealed-secrets/values.yaml
kubectl delete secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key=active
kubectl apply -n kube-system -f ~/Desktop/sealed-secrets-master.key
kubectl delete pod -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

## Install Argo and bootstrap cluster

```sh
make install-argocd
make get-argocd-password
make check-argocd-ready
```

## Use

```sh
argocd login argocd.apps.blah.cloud --sso --grpc-web
#login with GitHub account or admin password from above
argocd account update-password
argocd app list
```

## Cleanup

```sh
make cleanup
```

## Todo

* Move from traefik to NginX + cert-manager
* Add fluentbit to Argo
* Add kube-prometheus to Argo
