# K8s cluster bootstrap and app install

[![ArgoCD Status](https://argocd.tanzu.blah.cloud/api/badge?name=bootstrap&revision=true)](https://argocd.tanzu.blah.cloud/applications/bootstrap)

## Apply PSP

```sh
kubectl create clusterrolebinding default-tkg-admin-privileged-binding --clusterrole=psp:vmware-system-privileged --group=system:authenticated
```

## Apply Reg-cred syncer

```sh
kubectl apply -f manifests/registry-creds
```

### Apply reg cred secret

```sh
kubectl apply -f ~/Desktop/docker-creds.yaml
```

## Bitnami Sealed Secrets

### Install Sealed Secrets

```sh
helm upgrade --install sealed-secrets -n kube-system ./manifests/sealed-secrets -f manifests/sealed-secrets/values.yaml
```

### Seal secrets

```sh
kubeseal --format=yaml < ~/Desktop/docker-creds.yaml > manifests/registry-creds/docker-creds-sealed.yaml
kubeseal --format=yaml < ~/Desktop/argocd-secret.yaml > manifests/argocd/templates/argocd-sealed-secret.yaml
kubeseal --format=yaml < ~/Desktop/argocd-github-secret.yaml > manifests/argocd/templates/argocd-github-sealed-secret.yaml
kubeseal --format=yaml < ~/Desktop/argocd-rak8s-secret.yaml > manifests/argocd/templates/argocd-rak8s-sealed-secret.yaml
kubeseal --format=yaml < ~/Desktop/traefik-dnsprovider-config.yaml > manifests/traefik/templates/traefik-dnsprovider-config-sealed.yaml
kubeseal --format=yaml < ~/Desktop/argocd-notifications-secret.yaml > manifests/argocd-notifications/templates/argocd-notifications-secret-sealed.yaml
kubeseal --format=yaml < ~/Desktop/renovate-secret.yaml > manifests/renovate/templates/renovate-sealed-secret.yaml
kubeseal --format=yaml < ~/Desktop/keycloak-secret.yaml > manifests/keycloak/templates/keycloak-secret-sealed.yaml
kubeseal --format=yaml < ~/Desktop/keycloak-postgres-secret.yaml > manifests/keycloak/templates/keycloak-postgres-secret-sealed.yaml
kubeseal --format=yaml < ~/Desktop/argocd-workflows-sso.yaml  > manifests/argocd-workflows/templates/argocd-workflows-sso-sealed.yaml
kubeseal --format=yaml < ~/Desktop/argocd-workflows-minio.yaml  > manifests/minio/templates/argocd-workflows-minio-sealed.yaml
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

## Apply Prometheus CRDs

```sh
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.47.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.47.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.47.0/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.47.0/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.47.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.47.0/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.47.0/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml
```

## Create necessary secrets

```sh
kubectl apply -f manifests/argocd-workflows/templates
```

## Install Argo and bootstrap cluster

```sh
make install-argocd
make get-argocd-password
make check-argocd-ready
```

## Use

```sh
argocd login argocd.tanzu.blah.cloud --sso --grpc-web
#login with GitHub account or admin password from above
argocd account update-password
argocd app list
```

## Cleanup

```sh
make cleanup
```

## Todo

### Apps

* Knative serving samples <https://knative.dev/docs/serving/samples/>
* Investigate Istio vs Linkerd
* Move from Traefik to new ingress controller + cert-manager for TLS
* Add Tekton <https://github.com/tektoncd/pipeline>
* Investigate [Argo Events](https://github.com/argoproj/argo-events) and [Argo Rollouts](https://argoproj.github.io/argo-rollouts/) vs [Flagger](https://github.com/fluxcd/flagger) / [Knative Eventing](https://knative.dev/docs/eventing/) and [Serving](https://knative.dev/docs/serving/)
* Investifate KNative Operator <https://knative.dev/docs/install/knative-with-operators/>
* Investigate Argo Operator <https://github.com/argoproj-labs/argocd-operator>
* Add Reloader <https://github.com/stakater/Reloader>
* Add Renovate self-hosted <https://docs.renovatebot.com/self-hosting/>

### Organisational

* Refactor namespaces
* Refactor App hierarchy
* Refactor Apps into Projects
* Use sync waves
  * Example topology: <https://github.com/argoproj/argo-cd/issues/3516#issue-609473764>
* Deploy from tags/branches rather than master

### Security

* Remove all internal un/passwords and keys and turn into sealed secrets
* Make ArgoCD GitHub webhook authenticated
