.PHONY: install-prereqs install-argocd get-argocd-password proxy-argocd login-argocd watch-apps

list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

fresh: install-prereqs install-argocd get-argocd-password proxy-argocd login-argocd watch-apps

get-argocd-password:
	kubectl wait --for=condition=available deployment -l "app.kubernetes.io/name=argocd-server" -n argocd --timeout=600s
	$(eval ARGOPW := $(shell kubectl get secret -n argocd argocd-initial-admin-secret -o json | jq -r .data.password | base64 -d))
	echo ArgoCD password is: $(ARGOPW)
	$(MAKE) login-argocd ARGOPW=${ARGOPW}

login-argocd:
	argocd login localhost:8080 --insecure --plaintext --username=admin --password=$(ARGOPW)

watch-apps:
	watch -n 1 argocd app list

install-prereqs:
	kubectl create clusterrolebinding default-tkg-admin-privileged-binding --clusterrole=psp:vmware-system-privileged --group=system:authenticated || true
	kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.52.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagerconfigs.yaml
	kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.52.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
	kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.52.0/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
	kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.52.0/example/prometheus-operator-crd/monitoring.coreos.com_probes.yaml
	kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.52.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
	kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.52.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
	kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.52.0/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
	kubectl create -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.52.0/example/prometheus-operator-crd/monitoring.coreos.com_thanosrulers.yaml
	helm upgrade --install sealed-secrets -n kube-system ./manifests/sealed-secrets -f manifests/sealed-secrets/values.yaml
	kubectl wait --for=condition=available deployment -l "app.kubernetes.io/name=sealed-secrets" -n kube-system --timeout=300s
	kubeseal --format=yaml < ~/Desktop/ArgoCD-Secrets/docker-creds.yaml > manifests/registry-creds/02-docker-creds-sealed.yaml
	kubeseal --format=yaml < ~/Desktop/ArgoCD-Secrets/tanzu/argocd-secret.yaml > manifests/argocd/templates/argocd-sealed-secret.yaml
	kubeseal --format=yaml < ~/Desktop/ArgoCD-Secrets/tanzu/argocd-ns-target.yaml > manifests/argocd/templates/argocd-ns-target-sealed-secret.yaml
	kubeseal --format=yaml < ~/Desktop/ArgoCD-Secrets/argocd-github-secret.yaml > manifests/argocd/templates/argocd-github-sealed-secret.yaml
	kubeseal --format=yaml < ~/Desktop/ArgoCD-Secrets/argocd-notifications-secret.yaml > manifests/argocd-notifications/templates/argocd-notifications-secret-sealed.yaml
	kubeseal --format=yaml < ~/Desktop/ArgoCD-Secrets/renovate-secret.yaml > manifests/renovate/templates/renovate-sealed-secret.yaml
	kubeseal --format=yaml < ~/Desktop/ArgoCD-Secrets/keycloak-secret.yaml > manifests/keycloak/templates/keycloak-secret-sealed.yaml
	kubeseal --format=yaml < ~/Desktop/ArgoCD-Secrets/keycloak-postgres-secret.yaml > manifests/keycloak/templates/keycloak-postgres-secret-sealed.yaml
	kubeseal --format=yaml < ~/Desktop/ArgoCD-Secrets/argo-workflows-sso.yaml  > manifests/argocd-workflows/templates/argo-workflows-sso-sealed.yaml
	kubeseal --format=yaml < ~/Desktop/ArgoCD-Secrets/argo-workflows-minio.yaml  > manifests/argocd-workflows/templates/argo-workflows-minio-sealed.yaml
	kubeseal --format=yaml < ~/Desktop/ArgoCD-Secrets/argo-workflows-minio-minio.yaml  > manifests/minio-operator/templates/argo-workflows-minio-minio-sealed.yaml
	kubeseal --format=yaml < ~/Desktop/ArgoCD-Secrets/minio-tenant-secret.yaml  > manifests/minio-operator/templates/minio-tenant-secret-sealed.yaml
	kubeseal --format=yaml < ~/Desktop/ArgoCD-Secrets/cert-secret.yaml  > manifests/kube-prometheus-stack/templates/cert-secret-sealed.yaml
	kubeseal --format=yaml < ~/Desktop/ArgoCD-Secrets/cloudflare-api-token.yaml  > manifests/cert-manager/templates/cloudflare-api-token-sealed.yaml
	kubeseal --format=yaml < ~/Desktop/ArgoCD-Secrets/boilerjuice-creds.yaml > manifests/oil-monitor/boilerjuice-creds-sealed.yaml
	kubeseal --format=yaml < ~/Desktop/ArgoCD-Secrets/influxdb-auth.yaml > manifests/influxdb/templates/influxdb-auth-sealed.yaml
	git add .
	git commit -m "ArgoCD secret regen"
	git push
	kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > ~/Desktop/ArgoCD-Secrets/tanzu/sealed-secrets-master.key
	kubectl create ns argocd || true
	kubectl create ns minio || true
	kubectl create ns monitoring || true
	kubectl apply -f manifests/argocd-notifications/templates/
	kubectl apply -f manifests/argocd-workflows/templates/
	kubectl apply -f manifests/registry-creds/

install-argocd:
	kubectl create ns argocd || true
	kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/crds/appproject-crd.yaml
	kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/crds/application-crd.yaml
	helm upgrade --install argocd -n argocd ./manifests/argocd -f manifests/argocd/values.yaml

install-cert-manager:
	helm repo add jetstack https://charts.jetstack.io
	kubectl create ns cert-manager
	kubectl label ns cert-manager cert-manager.k8s.io/disable-validation=true
	kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v0.14.0/cert-manager.crds.yaml
	helm upgrade --install cert-manager --n cert-manager --version v0.14.0 jetstack/cert-manager
	kubectl apply -f resources/letsencrypt-issuer.yaml

cleanup:
	helm delete -n argocd argocd || true
	helm delete -n kube-system sealed-secrets || true
	kubectl get applications.argoproj.io -o name | sed -e 's/.*\///g' | xargs -I {} kubectl patch applications.argoproj.io {} -p '{"metadata":{"finalizers":[]}}' --type=merge
	kubectl get appprojects.argoproj.io -o name | sed -e 's/.*\///g' | xargs -I {} kubectl patch appprojects.argoproj.io {} -p '{"metadata":{"finalizers":[]}}' --type=merge
	kubectl delete appprojects.argoproj.io --all || true
	kubectl delete applications.argoproj.io --all || true
	kubectl delete crd applications.argoproj.io || true
	kubectl delete crd appprojects.argoproj.io || true
	kubectl delete apiservice v1beta1.metrics.k8s.io || true
	kubectl delete ns argocd || true
	kubectl delete ns infra || true
	kubectl delete ns buildkit || true
	kubectl delete ns buildkit-emu || true
	kubectl delete ns cheese || true
	kubectl delete ns ingress || true
	kubectl delete ns keycloak || true
	kubectl delete ns kibana || true
	kubectl delete ns elasticsearch || true
	kubectl delete ns knative || true
	kubectl delete ns logging || true
	kubectl delete ns minio || true
	kubectl delete ns monitoring || true
	kubectl delete ns qemu-binfmt || true
	kubectl delete ns quake || true
	kubectl delete ns renovate || true
	kubectl delete ns storage || true
	kubectl delete ns velero || true
	kubectl delete ns auth || true
	kubectl delete ns registry-creds-system || true
	kubectl delete ns kubernetes-dashboard || true
	kubectl delete crd alertmanagerconfigs.monitoring.coreos.com || true
	kubectl delete crd alertmanagers.monitoring.coreos.com || true
	kubectl delete crd podmonitors.monitoring.coreos.com || true
	kubectl delete crd probes.monitoring.coreos.com || true
	kubectl delete crd prometheuses.monitoring.coreos.com || true
	kubectl delete crd prometheusrules.monitoring.coreos.com || true
	kubectl delete crd servicemonitors.monitoring.coreos.com || true
	kubectl delete crd thanosrulers.monitoring.coreos.com || true
	kubectl delete crd sealedsecrets.bitnami.com || true
	kubectl get apiservice | grep False | awk '{print $1}' | xargs -I {} kubectl delete apiservice {} 
	kubectl delete all -l app.kubernetes.io/managed-by=Helm -A || true
	kubectl delete all -n default --all || true

proxy-argocd:
	kubectl port-forward -n argocd service/argocd-server 8080:80 &