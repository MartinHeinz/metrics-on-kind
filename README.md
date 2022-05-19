# Kubernetes Metrics on KinD

Self-contained KinD (Kubernetes in Docker) environment for testing custom and external Kubernetes metrics API and alpha/beta features of _HorizontalPodAutoscaler (HPA)_.

## Prerequisites

- Docker
- KinD
- `kubectl`
- `cfssl` (optional)

## Setup

Run `./setup.sh` to create KinD cluster with `metrics-server`, Prometheus Operator, Prometheus, Prometheus Adapter, sample application and Service Monitor.

`custom-metrics-apiserver` which is part of Prometheus Adapter, needs serving certificate and key. These are generated in `cm-adapter-serving-certs.yaml` for your convenience, but you can generate new ones using `certs.sh`

Be aware that this setup is meant for testing and should be used in production environment, especially not the pre-generated certificates.

## Usage

After running `setup.sh`, use the commands from output.

`hpa.yaml` contains sample HPAs that can be tested against prepopulated metrics.

Additional commands:

To verify availability of metrics run:

```bash
kubectl top nodes
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq .
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods" | jq .
```

Generate application load:

```bash
# 300m of CPU for 10min
kubectl run curl --image=curlimages/curl:7.83.1 \
  --rm -it --restart=Never -- \
  curl --data "millicores=300&durationSec=600" http://resource-consumer:8080/ConsumeCPU

# 500Mi of RAM for 10min
kubectl run curl --image=curlimages/curl:7.83.1 \
  --rm -it --restart=Never -- \
  curl --data "megabytes=500&durationSec=600" http://resource-consumer:8080/ConsumeMem
```

Create metrics:

```bash
# Create custom metric with name custom_metric and value 100, present for 10min
kubectl run curl --image=curlimages/curl:7.83.1 \
  --rm -it --restart=Never -- \
  curl --data "metric=custom_metric&delta=100&durationSec=600" http://resource-consumer:8080/BumpMetric

# View metrics endpoint
kubectl run curl --image=curlimages/curl:7.83.1 \
  --rm -it --restart=Never -- \
  curl -XGET http://resource-consumer:8080/metrics
```

Connect to Prometheus dashboard:

```bash
kubectl -n custom-metrics port-forward service/prometheus-operated 9090
# View at localhost:9090
```

View prepopulated custom/external API metrics:

```bash
kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1 | jq .
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/default/pods/*/custom_metric" | jq .

kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1" | jq .
kubectl get --raw /apis/external.metrics.k8s.io/v1beta1/namespaces/default/external_queue_messages_ready | jq .
```

Clean-up:

```bash
kind delete clusters autoscaling
```

### Resources

Inspired/Adjusted from:

- https://github.com/stefanprodan/k8s-prom-hpa
- https://github.com/kubernetes-sigs/prometheus-adapter/blob/master/docs/walkthrough.md