# Testing with webhooks

## Sending events to broker

```sh
kubectl attach curl -it
```

To hello:

```sh
curl -f "http://broker-ingress.knative-eventing.svc.cluster.local/knative/default" \
-X POST \
-H "Ce-Id: say-hello" \
-H "Ce-Specversion: 1.0" \
-H "Ce-Type: greeting" \
-H "Ce-Source: not-sendoff" \
-H "Content-Type: application/json" \
-d '{"msg":"Hello Knative!"}'
```

To goodbye:

```sh
curl -v "http://broker-ingress.knative-eventing.svc.cluster.local/knative/default" \
-X POST \
-H "Ce-Id: say-goodbye" \
-H "Ce-Specversion: 1.0" \
-H "Ce-Type: not-greeting" \
-H "Ce-Source: sendoff" \
-H "Content-Type: application/json" \
-d '{"msg":"Goodbye Knative!"}'
```

To both:

```sh
curl -v "http://broker-ingress.knative-eventing.svc.cluster.local/knative/default" \
-X POST \
-H "Ce-Id: say-hello-goodbye" \
-H "Ce-Specversion: 1.0" \
-H "Ce-Type: greeting" \
-H "Ce-Source: sendoff" \
-H "Content-Type: application/json" \
-d '{"msg":"Hello Knative! Goodbye Knative!"}'
```

## Validation

```sh
kubectl logs -l app=hello-display --tail=100
kubectl logs -l app=goodbye-display --tail=100
```
