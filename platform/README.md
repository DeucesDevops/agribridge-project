# Platform add-ons

kOps already installs the AWS Load Balancer Controller, the EBS CSI driver and
the pod-identity webhook. Install the rest with Helm after
`terraform apply -var attach_irsa=true`.

Run these from the repository root, with `KUBECONFIG` pointing at the cluster.
Replace the role ARNs with `terraform output`.

```sh
helm repo add external-secrets https://charts.external-secrets.io
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl apply -f platform/storage-class.yaml

SECRETS_ROLE="$(terraform -chdir=terraform output -raw external_secrets_role_arn)"
helm upgrade --install external-secrets external-secrets/external-secrets \
  --version 2.15.0 \
  --namespace external-secrets --create-namespace \
  --set serviceAccount.name=external-secrets \
  --set-string "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=${SECRETS_ROLE}"

DNS_ROLE="$(terraform -chdir=terraform output -raw external_dns_role_arn)"
helm upgrade --install external-dns external-dns/external-dns \
  --version 1.23.0 \
  --namespace external-dns --create-namespace \
  --set serviceAccount.name=external-dns \
  --set provider.name=aws \
  --set policy=upsert-only \
  --set txtOwnerId=agribridge \
  --set "domainFilters[0]=$(terraform -chdir=terraform output -raw zone_name)" \
  --set-string "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=${DNS_ROLE}"

helm upgrade --install loki grafana/loki \
  --version 7.6.0 \
  --namespace monitoring --create-namespace \
  --values platform/loki-values.yaml

helm upgrade --install tempo grafana/tempo \
  --version 1.24.4 \
  --namespace monitoring \
  --values platform/tempo-values.yaml

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --version 93.3.1 \
  --namespace monitoring \
  --values platform/prometheus-values.yaml

helm upgrade --install promtail grafana/promtail \
  --version 6.17.1 \
  --namespace monitoring \
  --values platform/promtail-values.yaml
```

Helm may print a deprecation warning for the Tempo and Promtail charts. Those
charts still install the single-process collectors used here.

Grafana stays inside the cluster. Read the generated admin password and open it
locally:

```sh
kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d
echo
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```

The user is `admin`. Prometheus, Loki and Tempo are already added as Grafana
datasources. The application chart publishes a ServiceMonitor for the API.
The API does not send traces, so Tempo stays empty until a tracer is added.

Worker nodes in `kops/cluster.yaml` are `t3.large`. If pods stay Pending,
raise `maxSize` on the node instance groups and run `kops update cluster --yes`.
