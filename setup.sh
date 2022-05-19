kind create cluster --config ./cluster.yaml --name autoscaling --image=kindest/node:v1.23.6

echo -e "\nInstalling metrics-server...\n"

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.5.0/components.yaml
kubectl patch -n kube-system deployment metrics-server --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

echo -e "\nTo verify availability of metrics run:\n"
echo -e 'kubectl top nodes'
echo -e 'kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq .'
echo -e 'kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods" | jq .'

echo -e "\nDeploying load tester app...\n"

kubectl create deployment resource-consumer --image=gcr.io/k8s-staging-e2e-test-images/resource-consumer:1.11
kubectl set resources deployment resource-consumer --requests=cpu=500m,memory=256Mi
kubectl apply -f service.yaml

echo -e "\nTo load test:\n"
echo -e 'kubectl run curl --image=curlimages/curl:7.83.1 --rm -it --restart=Never -- curl --data "millicores=300&durationSec=600" http://resource-consumer:8080/ConsumeCPU'

echo -e "\nTo view application metrics:\n"

echo -e 'kubectl run curl --image=curlimages/curl:7.83.1 --rm -it --restart=Never -- curl --data "metric=custom_metric&delta=100&durationSec=600" http://resource-consumer:8080/BumpMetric'
echo -e 'kubectl run curl --image=curlimages/curl:7.83.1 --rm -it --restart=Never -- curl --data "metric=external_queue_messages_ready&delta=100&durationSec=600" http://resource-consumer:8080/BumpMetric'
echo -e 'kubectl run curl --image=curlimages/curl:7.83.1 --rm -it --restart=Never -- curl -XGET http://resource-consumer:8080/metrics'

echo -e "\nDeploy Prometheus Operator...\n"

kubectl create namespace prom
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/4d3e02cdb65407c29219369c9c74b4402f19c18b/bundle.yaml

kubectl create namespace custom-metrics

kubectl apply -f service-monitor.yaml
kubectl apply -f prometheus.yaml

echo -e "\nTo access Prometheus dashboard:\n"
echo -e 'kubectl -n custom-metrics port-forward service/prometheus-operated 9090'

echo -e "\nInstalling Prometheus adapter...\n"

kubectl apply -f cm-adapter-serving-certs.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/prometheus-adapter/9008b12a0173e2604e794c1614081b63c17e0340/deploy/manifests/custom-metrics-apiserver-auth-delegator-cluster-role-binding.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/prometheus-adapter/9008b12a0173e2604e794c1614081b63c17e0340/deploy/manifests/custom-metrics-apiserver-auth-reader-role-binding.yaml
kubectl apply -f custom-metrics-apiserver-deployment.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/prometheus-adapter/9008b12a0173e2604e794c1614081b63c17e0340/deploy/manifests/custom-metrics-apiserver-resource-reader-cluster-role-binding.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/prometheus-adapter/9008b12a0173e2604e794c1614081b63c17e0340/deploy/manifests/custom-metrics-apiserver-service-account.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/prometheus-adapter/9008b12a0173e2604e794c1614081b63c17e0340/deploy/manifests/custom-metrics-apiserver-service.yaml

kubectl apply -f custom-metrics-apiservice.yaml  # Because upstream has a wrong apiVersion
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/prometheus-adapter/9008b12a0173e2604e794c1614081b63c17e0340/deploy/manifests/custom-metrics-cluster-role.yaml
kubectl apply -f custom-metrics-config-map.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/prometheus-adapter/9008b12a0173e2604e794c1614081b63c17e0340/deploy/manifests/custom-metrics-resource-reader-cluster-role.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/prometheus-adapter/9008b12a0173e2604e794c1614081b63c17e0340/deploy/manifests/hpa-custom-metrics-cluster-role-binding.yaml

echo -e "\nPopulating custom and external metrics...\n"

kubectl run curl --image=curlimages/curl:7.83.1 --rm -it --restart=Never -- curl --data "metric=custom_metric&delta=100&durationSec=600" http://resource-consumer:8080/BumpMetric
kubectl run curl --image=curlimages/curl:7.83.1 --rm -it --restart=Never -- curl --data "metric=external_queue_messages_ready&delta=100&durationSec=600" http://resource-consumer:8080/BumpMetric


echo -e "\nTo query/verify custom metrics:\n"
echo -e 'kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1 | jq .'
echo -e 'kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/default/pods/*/custom_metric" | jq .'


echo -e 'kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1" | jq .'
echo -e 'kubectl get --raw /apis/external.metrics.k8s.io/v1beta1/namespaces/default/external_queue_messages_ready | jq .'

echo -e "\nAll components deployed. To clean up run 'kind delete clusters autoscaling'"