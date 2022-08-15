# helm
Helm charts for FID and Zookeeper deployment

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

## TL;DR

```console
$ helm repo add radiantone https://radiantlogic-devops.github.io/helm
$ helm install my-zk-release radiantone/zookeeper
$ helm install my-fid-release radiantone/fid --set fid.license=<license> \
--set zk.connectionString="my-zk-release-zookeeper:2181" --set zk.ruok="http://my-zk-release-zookeeper:8080/commands/ruok"
```

## Add Helm repo

Once Helm has been set up correctly, add the repo as follows:

```
helm repo add radiantone https://radiantlogic-devops.github.io/helm
```

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo radiantone` to see the charts.

## Remove Helm repo

```
helm repo remove radiantone
```

## Install Zookeeper

### Prerequisites
* Kubernetes 1.18+
* Helm 3

### Charts
#### Install Zookeeper
* Install Zookeeper with default values
```
helm install --namespace=<name space> <release name> radiantone/zookeeper
```
* Install Zookeeper with overridden values
```
helm install --namespace=<name space> <release name> radiantone/zookeeper \
--set replicaCount="5"
```
* Install Zookeeper with Persistence Enabled

```
helm install --namespace=<name space> <release name> radiantone/zookeeper  --set persistence.enabled="true" --set persistence.storageClass="<storage class name>"
```

* List Zookeeper releases
```
helm list --namespace=<name space>
```
* Upgrade a Zookeeper release
```
helm upgrade --namespace=<name space> <release name> radiantone/zookeeper
```
* Delete a Zookeeper release
```
helm uninstall --namespace=<name space> <release name>
```

## Install FID

### Prerequisites
* Kubernetes 1.18+
* Helm 3

### Charts
#### Install FID
* Install FID with default values
```
helm install --namespace=<name space> <release name> radiantone/fid
```
* Install FID with overridden values
```
helm install --namespace=<name space> <release name> radiantone/fid \
--set zk.connectionString="zk.dev:2181" \
--set zk.ruok="http://zk.dev:8080/commands/ruok" \
--set fid.license="<FID cluster license>" \
--set fid.rootPassword="test1234"
```
Note: Curly brackets in the liense must be escaped ```--set fid.license="\{rlib\}xxx"```

* Install FID with Persistence Enabled

    - [Persisitent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) (PV/PVC) can be enabled to enable storage for FID
    - A suitable [storage class](https://kubernetes.io/docs/concepts/storage/storage-classes/) should also be selected
```
helm install --namespace=<name space> <release name> radiantone/fid \
--set zk.clusterName=my-demo-cluster \
--set zk.connectionString="zk.dev:2181" \
--set zk.ruok="http://zk.dev:8080/commands/ruok" \
--set fid.license="<FID cluster license>" \
--set persistence.enabled="true" \
--set persistence.storageClass="<storage class type>" \
--set fid.rootPassword="test1234"

```

* Install FID with metrics Enabled

    - FID has a capability to forward the metrics to Prometheus for event/metrics monitoring.

    - Learn more about prometheus [here](https://prometheus.io)

    - Metrics from Prometheus can be visualized using [Grafana](https://grafana.com/grafana/) with available dashboards.


* Prerequisites
    - Zookeeper Deployed with Persistence enabled
    - Prometheus Deployed and push gateway URL available
    - To deploy Prometheus follow the documentation [here](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md)
    - To deploy Grafana follow the documentation [here](https://grafana.com/docs/agent/latest/operator/helm-getting-started/)

```
helm install --namespace=<name space> <release name> radiantone/fid \
--set zk.clusterName=my-demo-cluster \
--set zk.connectionString="zk.dev:2181" \
--set zk.ruok="http://zk.dev:8080/commands/ruok" \
--set fid.license="<FID cluster license>" \
--set persistence.enabled="true" \
--set persistence.storageClass="<storage class type>" \
--set fid.rootPassword="test1234"
--set metrics.enabled="true" \
--set metrics.pushMode="true" \
--set metrics.pushGateway="<pushGateway URL>" \
```

* Install FID with Log Forwarding Enabled.

    - FID has a capability of forwarding the logs to Elasticsearch using FluentD

    - These logs(data) from elasticsearch can be visualized using Kibana

    - Lean more about Elasticsearch [here](https://www.elastic.co)

    - Learn more about Kibana [here](https://www.elastic.co/kibana?ultron=B-Stack-Trials-AMER-US-W-Exact&gambit=Stack-Kibana&blade=adwords-s&hulk=paid&Device=c&thor=kibana&gclid=Cj0KCQjw3eeXBhD7ARIsAHjssr8Yhz4S7AmKvoc4LxgrfG7EDr0b6i8i7FRhBBmth7JK_ylVOvv-FOEaAlp5EALw_wcB)

* Prerequisites

    - Zookeeper Deployed with Persistence enabled
    - Elasticsearch Deployed with Kibana
    - To deploy Elasticsearch follow the documentation [here](https://artifacthub.io/packages/helm/elastic/elasticsearch)
    - To deploy Kibana follow the documentation [here](https://artifacthub.io/packages/helm/elastic/kibana)
    - Elasticsearch Host URL available

```
helm install --namespace=<name space> <release name> radiantone/fid \
--set zk.clusterName=my-demo-cluster \
--set zk.connectionString="zk.dev:2181" \
--set zk.ruok="http://zk.dev:8080/commands/ruok" \
--set fid.license="<FID cluster license>" \
--set persistence.enabled="true" \
--set persistence.storageClass="<storage class type>" \
--set fid.rootPassword="test1234" \
--set metrics.enabled="true" \
--set metrics.fluentd.enabled="true" \
--set metrics.fluentd.elasticSearchHost="<elasticSearchHost URL"
```


* List FID releases
```
helm list --namespace=<name space>
```
* Upgrade FID release
```
helm upgrade --namespace=<name space> <release name> radiantone/fid --set image.tag=7.3.17
```
* Delete FID release
```
helm uninstall --namespace=<name space> <release name>
```
