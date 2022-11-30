# helm
Helm chart for FID deployment

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

## TL;DR
```console
helm repo add radiantone https://radiantlogic-devops.github.io/helm
helm install fid radiantone/fid --set fid.license=<license> --set dependencies.zookeeper.enabled=true
```

Install Zookeeper and FID seperately

```
helm repo add radiantone https://radiantlogic-devops.github.io/helm
helm install zookeeper radiantone/zookeeper
helm install fid radiantone/fid --set fid.license=<license> \
--set zk.connectionString="zookeeper:2181" --set zk.ruok="http://zookeeper:8080/commands/ruok"
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

## Install FID/ZOOKEEPER

### Prerequisites
* Kubernetes 1.18+
* Helm 3

## Charts

## Install Zookeeper

### Install zookeeper with default Values

```
helm install --namespace=<name space> <release name>  radiantone/zookeeper
```

### Install Zookeeper with persistence enabled

 * [Persisitent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) (PV/PVC) can be enabled to enable storage for FID
 * A suitable [storage class](https://kubernetes.io/docs/concepts/storage/storage-classes/) should also be selected

```
helm install --namespace=<name space> <release name> radiantone/zookeeper  --set persistence.enabled="true" --set persistence.storageClass="<storage class name>"
```



## Install FID
* Install FID with default values
```
helm install --namespace=<name space> <release name> radiantone/fid
```
* Install FID with local Zookeeper
```
helm upgrade --install --namespace=<name space> <release name> radiantone/fid --set zk.external=false --set zk.clusterName=my-demo-cluster
```

* Install FID with external Zookeeper
```
helm install --namespace=<name space> <release name> radiantone/fid \
--set zk.clusterName=my-demo-cluster \
--set zk.connectionString="zk.dev:2181" \
--set zk.ruok="http://zk.dev:8080/commands/ruok" \
--set fid.license="<FID cluster license>" \
--set fid.rootPassword="test1234"
```
Note: Curly brackets in the license must be escaped ```--set fid.license="\{rlib\}xxx"```

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


## Hooks 

* Helm Hooks have been added to allow intervention at certain point (install, upgrade, rollback and delete) of lifecycle
* These hooks can be found under hooks folder in the templates.
* Available hooks are pre/post Install, Upgrade, Rollback and Delete
* A service account with permissions to perform actions required by helm hooks can also be created by enabling (hooks-sa.yaml)
* All the hook templates can be modified according to the use-case

#### Install FID with Hooks Enabled
```
helm install --namespace=<name space> <release name> radiantone/fid \
--set zk.clusterName=my-demo-cluster \
--set zk.connectionString="zk.dev:2181" \
--set zk.ruok="http://zk.dev:8080/commands/ruok" \
--set fid.license="<FID cluster license>" \
--set fid.rootPassword="test1234"
--set hooks.hooks-sa.enabled="true"
--set hooks.pre_install.enabled="true"
--set hooks.post_install.enabled="true"
--set hooks.pre_upgrade.enabled="true"
--set hooks.post_upgrade.enabled="true"
--set hooks.pre_rollback.enabled="true"
--set hooks.post_rollback.enabled="true"
--set hooks.pre_delete.enabled="true"
--set hooks.post_delete.enabled="true"
```

## Migration CRON Job

* A CRON job to generate migration export and push it to a S3 has been added (migration-cronjob.yaml)
* CRON job can be enabled through the values file and the CRON expression can be set to run the job accordingly.
* The service account (similar to one required for Hooks) should be enabled for the CRON job (hooks-sa.yaml)

#### Install FID with Migration CRON Job enabled
```
helm install --namespace=<name space> <release name> radiantone/fid \
--set zk.clusterName=my-demo-cluster \
--set zk.connectionString="zk.dev:2181" \
--set zk.ruok="http://zk.dev:8080/commands/ruok" \
--set fid.license="<FID cluster license>" \
--set fid.rootPassword="test1234"
--set hooks.hooks-sa.enabled="true"
--set cronjob.migration.enabled="true"
--set cronjob.migration.schedule="0 0 * * *"
--set cronjob.migration.s3="s3://fid-exports/cronjob"
```



