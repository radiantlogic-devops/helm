# FID

![Version: 1.0.1](https://img.shields.io/badge/Version-1.0.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 8.0.0](https://img.shields.io/badge/AppVersion-8.0.0-informational?style=flat-square)

A Helm chart for FID Kubernetes deployment

## Prerequisites

* Kubernetes 1.24+
* Helm 3

## TL;DR

```console
helm repo add radiantone https://radiantlogic-devops.github.io/helm
helm install fid radiantone/fid --set fid.license=<license> --set dependencies.zookeeper.enabled=true
```

**Homepage:** <https://radiantlogic-devops.github.io/helm>

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

## Add Helm repo

Once Helm has been set up correctly, add the repo as follows:

```

helm repo add radiantone https://radiantlogic-devops.github.io/helm

```

If you already added this repo, run `helm repo update` to retrieve the latest versions of the packages.  You can then run `helm search repo radiantone` to see the charts.

## Remove Helm repo

```
helm repo remove radiantone
```

## Deploy FID and Zookeeper

* FID and Zookeeper can be deployed in two different ways using the current HELM charts

* Both FID and Zookeeper are of type statefulset, and will need persistence enabled for data to persist.
* - Zookeeper can deployed as [dependency](https://helm.sh/docs/helm/helm_dependency/) chart to FID
* There are two different possible ways to deploy FID&ZK, mentioned in the document
  * Using the "helm install" command and "--set" option
  * Using the "helm install" command and "--values" option for which a modified values.yaml file either locally or external values.yaml file is required
* A valid License is required before continuing to deployment
* For queries around licenses, contact <support@radiantlogic.com>

### DEPLOY FID WITH ZOOKEEPER AS A DEPENDENCY (--set)

#### Below gives the command to deploy FID with Zookeeper as a dependency using the HELM install command and "--set" values option

```
helm install --namespace=<name space> <release name> radiantone/fid \
--set dependencies.zookeeper.enabled=true
--set zk.clusterName=my-demo-cluster \
--set fid.license="<FID cluster license>" \
--set fid.rootPassword="test1234"
```

>Note: Curly brackets in the license must be escaped ```--set fid.license="\{rlib\}xxx"```

### DEPLOY FID WITH ZOOKEEPER AS A DEPENDENCY (--values)

#### Below gives the command to deploy FID with Zookeeper as a dependency using the HELM install command and "--values" through values.yaml file option

* Any modifications to the values.yaml of the zookeeper, can also done through the FID values.yaml file
* The dependencies section of the values.yaml file (fid) should be modified in the following way

```yaml
dependencies:
  zookeeper:
    enabled: true
# Values file Inputs for the dependency charts.
zookeeper:
  fullnameOverride: zookeeper
  replicaCount: 3
  persistence:
    enabled: true
    storageClass: "" #gp2/gp3
```

* Additional Values of [zookeeper](https://github.com/radiantlogic-devops/helm/blob/master/charts/zookeeper/values.yaml) can be included in the above.

Commands:

Update the HELM Dependencies

>NOTE If you are deploying the FID by downloading (or cloning) the FID helm chart you will need to run the command below manually

```yaml
helm dependency update
```

Deploy FID (using the values file)

value.yaml file

```yaml
replicaCount: 1
image:
  repository: radiantone/fid
  tag: ""
fid:
  rootUser: "cn=Directory Manager"
  rootPassword: "Welcome1234"
  license: "[FID Cluster License]"
resources:
  limits:
    cpu: 1
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
dependencies:
  zookeeper:
    enabled: true
# Values file Inputs for the dependency charts.
zookeeper:
  fullnameOverride: zookeeper
  replicaCount: 3
  persistence:
    enabled: false
    storageClass: ""
```

```yaml
helm -n <namespace> install <release name> radiantone/fid --values <path to the values file> # updated values file
```

>NOTE: Special Characters in the license need not be escaped when deploying FID using the values file.

## DEPLOYING ZOOKEEPER AND FID INDIVIDUALLY

## Deploying Zookeeper

* FID needs Zookeeper to be deployed ahead of its deployment
* You can find the Zookeeper chart repository [here](https://github.com/radiantlogic-devops/helm/tree/master/charts/zookeeper)
* Zookeeper is a [statefulsets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) type deployment and requires [PVC](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) in order to maintain its state
* The PVCs for zookeeper are dynamically created based on the type and size provided during the deployment
* Official Radiantone Zookeeper docker images can be found [here](https://hub.docker.com/r/radiantone/zookeeper)
* For better performance and high availability , it is recommended to run Zookeeper as an external type and the documentation covers external-zookeeper installation only

```yaml
helm install --namespace=<name space> <release name> radiantone/zookeeper
```

### **Sample Values File to deploy Zookeeper with overridden values**

[https://helm.sh/docs/helm/helm_install/](https://helm.sh/docs/helm/helm_install/)

* Values files can be used to override any default values during the deployment
* The sample values file below can be modified according to the usage and be used to deploy zookeeper

```yaml

replicaCount: 3

resources:
  limits:
    cpu: 1
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi
```

> **NOTE:** A full values.yaml file can be found in the Helm Repo. The above contains ket:value pairs that usually modified.
>

**Command to deploy zookeeper in desired namespace using a values file for overriding default values.**

```yaml
helm -n <namespace> install <release name> radiantone/zookeeper --values <path to the values file>
```

**DEPLOY ZOOKEEPER WITH PERSISTENCE ENABLED**

To deploy zookeeper with persisitence enabled , make the following changes to the values file above , save and run the command

> **NOTE:** The changes below should can be done either to the values.yaml (full) or the one that has been mentioned above.
>

```yaml
persistence:
  enabled: true
  ## If defined, storageClassName: <storageClass>
  ## If set to "-", storageClassName: "", which disables dynamic provisioning
  ## If undefined (the default) or set to null, no storageClassName spec is
  ##   set, choosing the default provisioner.  (gp2 on AWS, azure-disk on
  ##   Azure, standard on GKE, AWS & OpenStack)
  ##
  # storageClass: "-"
  storageClass: "gp2/gp3" #storageClass is dependent on the cloud provider
  accessModes:
  - ReadWriteOnce
  size: 10Gi # provide storage according to the usage
  annotations: {}
```

Command:

```yaml
helm -n <namespace> install <release name> radiantone/zookeeper --values <path to the values file>
```

**DEPLOY ZOOKEEPER WITH METRICS ENABLED**

To deploy zookeeper with metrics enabled , make the following changes to the values file above , save and run the command

> **NOTE:** Deploying Zookeeper with metrics enabled will need persistence to be enabled and also requires Prometheus, Grafana, ElasticSearch and Kibana deployed.
>

```yaml
metrics:
  enabled: true
  annotations: {}
  zk_conn: localhost:2181
  pushMode: true
  pushGateway: http://prometheus-pushgateway:9091
  fluentd:
    enabled: true
    configFile: /fluentd/etc/fluent.conf
    elasticSearchHost: elasticsearch-master
```

Command:

```yaml
helm -n <namespace> install <release name> radiantone/zookeeper --values <path to the values file>
```

### Deploy Zookeeper using “—set “ in HELM

Additionally **“—set”** can be used to set values and override the values in the values.yaml file

```yaml
helm install --namespace=<name space> <release name> radiantone/zookeeper \
--set replicaCount="<desired replica count>"
```

**DEPLOYING ZOOKEEPER WITH PERSISITENCE ENABLED**

```yaml
helm install --namespace=<name space> <release name> radiantone/zookeeper  --set persistence.enabled="true" --set persistence.storageClass="<storage class name>"
```

**DEPLOYING ZOOKEEPER WITH METRICS ENABLED**

```yaml
helm install --namespace=<name space> <release name> radiantone/zookeeper \
--set persistence.enabled="true" \
--set persistence.storageClass="<storage class name>" \
--set metrics.enabled="true" \
--set metrics.pushgateway="http://prometheus-pushgateway:9091" \
--set metrics.fluentd.enabled="true" \
--set metrics.fluentd.elasticSearchHost="elasticsearch-master"
```

> NOTE: The pushgatewayURL (prometheus) and ELASTICSEARCH host should be adjusted accordingly.
>

## DEPLOYING FID

* The HELM chart repository for FID can be found [here](https://github.com/radiantlogic-devops/helm/tree/master/charts/fid)
* FID is a [statefulset](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) type deployment and will require PVC to maintain its state
* FID is dependent on Zookeeper
* The official docker images for [FID](https://hub.docker.com/r/radiantone/fid) can be found here
* FID has built in checks that check if
  * Zookeeper is writable
  * Zookeeper is reachable
  * Migration is enabled
  * Metrics/Logging is enabled

**DEPLOYING USING THE VALUES.YAML FILE**

* FID has extensive list of modifications available through the [values.yaml](https://github.com/radiantlogic-devops/helm/blob/master/charts/fid/values.yaml) file.

*Sample minimal values.yaml file*

```yaml
replicaCount: 1
image:
  repository: radiantone/fid
  tag: "" #7.4.x
fid:
  rootUser: "cn=Directory Manager"
  rootPassword: "Welcome1234"
  license: "[FID Cluster License]"
  mountSecrets: false
resources:
  limits:
    cpu: 1
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
persistence:
  enabled: false
  storageClass: "default"
  accessModes:
  - ReadWriteOnce
  size: 10Gi
```

```yaml
helm install --namespace=<name space> <release name> radiantone/fid --values <path_to_modified_values.yaml>
```

**DEPLOY FID WITH PERSISTENCE ENABLED**

To deploy FID with persisitence enabled , make the following changes to the values file, save and run the command

> **NOTE:** The changes below should can be done either to the values.yaml(full) or the one that has been mentioned above.
>

```yaml
replicaCount: 1
image:
  repository: radiantone/fid
  tag: "" #7.4.x
fid:
  rootUser: "cn=Directory Manager"
  rootPassword: "Welcome1234"
  license: "[FID Cluster License]"
  mountSecrets: false
resources:
  limits:
    cpu: 1
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
persistence:
  enabled: true
  storageClass: "gp3" #Changes with cloud provider (standard, default, gp2, efs)
  accessModes:
  - ReadWriteOnce
  size: 10Gi
```

```yaml
helm install --namespace=<name space> <release name> radiantone/fid --values <path_to_modified_values.yaml>
```

#### To get DEBUG logs of deployment

```yaml
helm install --namespace=<name space> <release name> radiantone/fid --values <path_to_modified_values.yaml> --debug
```

**DEPLOYING FID WITH METRICS ENABLED**

To deploy FID with metrics enabled , make the following changes to the values file, save and run the command

> **NOTE:** Deploying FID with metrics enabled will need persistence to be enabled and also requires Prometheus, Grafana, ElasticSearch and Kibana deployed.

- Persisitence need to be enabled to enabled both logging or metrics
- Fluentd needs to be set to true to enable logging
- For splunk, to provide source, sourcetype, input them under aggregators.
- For splunk, to provide, custom source, sourcetype, index, use individual logs (splunk_index,splunk_source, splunk_sourcetype)
- Aggregators, Logs and key:value pairs for logs and aggregators can be added dynamically
- custom_index can be provided for each log individually and it takes precedence

```yaml
replicaCount: 1
image:
  repository: radiantone/fid
  tag: "" #7.4.x
fid:
  rootUser: "cn=Directory Manager"
  rootPassword: "Welcome1234"
  license: "[FID Cluster License]"
  mountSecrets: false
resources:
  limits:
    cpu: 1
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
persistence:
  enabled: true
  storageClass: "gp3" #Changes with cloud provider (standard, default, gp2, efs)
  accessModes:
  - ReadWriteOnce
  size: 10Gi
metrics:
  enabled: true
  image: radiantone/fid-exporter
  imageTag: latest
  annotations: {}
  pushMode: true
  pushGateway: http://prometheus-server:9091
  pushMetricCron: "* * * * *"
  fluentd:
    enabled: false
    logs:
      vds_server:
        enabled: true
        path: "/opt/radiantone/vds/vds_server/logs/vds_server.log"
        index: vds_server.log
        #custom_index:
      vds_events:
        enabled: true
        path: "/opt/radiantone/vds/vds_server/logs/vds_events.log"
        index: vds_events.log
        #custom_index:
    configFile: /fluentd/etc/fluent.conf
    aggregators: []
      # - type: "elasticsearch"
      #   host: "elasticsearch-master"
      #   port: "9200"
      # - type: "elasticsearch"
      #   host: "https://elasticsearch-master.local"
      #   port: "9200"
      #   scheme: "https"
      #   user: "xxxx"
      #   password: "xxxx"
      # - type: "opensearch"
      #   host: "opensearch-cluster-master"
      #   port: "9200"
      # - type: "splunk_hec"
      #   hec_hostname: "splunk-s1-standalone-service.splunk-operator.svc.cluster.local"
      #   hec_port: "8088"
      #   hec_token: ""
      #   hec_index: ""
```

```yaml
helm install --namespace=<name space> <release name> radiantone/fid --values <path_to_modified_values.yaml>
```

#### To get DEBUG logs of deployment

```yaml
helm install --namespace=<name space> <release name> radiantone/fid --values <path_to_modified_values.yaml> --debug
```

**DEPLOYING FID WITH DEFAULT VALUES (--set)**

> NOTE: Zookeeper should be installed prior to running the command below and FID License is required.
>

```yaml
helm install --namespace=<name space> <release name> radiantone/fid \
--set zk.clusterName=<cluster name> \
--set zk.connectionString="zk.<zookeeper namespace>:2181" \
--set zk.ruok="http://zk.<zookeeper namespace>:8080/commands/ruok" \
--set fid.license="<FID cluster license>" \
--set fid.image.tag="7.4.x"
--set fid.rootPassword="test1234"
```

> Curly brackets in the license must be escaped `--set fid.license="\{rlib\}xxx"`
>

## Upgrade FID release

```yaml
helm upgrade --namespace=<name space> <release name> radiantone/fid --set image.tag=7.3.17
```

## Delete FID release

```yaml
helm uninstall --namespace=<name space> <release name>
```

## **Detach**

* The Detach option enables a clean removal of the scaled down node by deleting its components/details from Zookeeper

## **Migration**

* FID helm chart has an otion to deploy the application using a pre-existing migration export
* The application deployed will have the migration imported and the application starts up with the imported data

```yaml
  migration:
  ## Migration file that will be imported during first install (export.zip)
  # url: https://raw.githubusercontent.com/radiantlogic-devops/docker-compose/master/05-monitoring-stack/configs/fid/export.zip
    url:
```

* A valid "url" where the migration export file is present has to be provided like in the above example.

## **Post Migration Script**

* FID Helm chart provides an option to run a script post migration

```yaml
  migration:
  ## Migration file that will be imported during first install (export.zip)
  # url: https://raw.githubusercontent.com/radiantlogic-devops/docker-compose/master/05-monitoring-stack/configs/fid/export.zip
    url:
  ## Post migration script to be run after install (configure_fid.sh)
    script:
```

## **Follower Only**

* FID Helm chart provides an option to deploy Follower Only nodes
* To know the details about Follower Only nodes and their function, please refer to the product documentation
* Follower Only nodes are deployed as a seperate statefulset application

```yaml
  followerOnly:
    enabled: false
    minReplicas: 1
    maxReplicas: 3
    targetCPUUtilizationPercentage: 80
    # targetMemoryUtilizationPercentage: 80
    ## Detach from cluster on termination
    detach: true
  livenessProbe:
    initialDelaySeconds: 60
    timeoutSeconds: 5
  readinessProbe:
    initialDelaySeconds: 120
    timeoutSeconds: 5
```

* To enable followerOnly nodes, set the enabled: to true (enabled:true)
* Minimum and Maximum replicas can also be set for follower only nodes and can be controlled as per requirement
* "Detach" option is also available for the follower only nodes.

## **Metrics&Logging**

* When "metrics" is enabled, a sidecar container (fid-exporter) is created that collects and publishes metrics and logs for the FID application.

### Metrics

* FID Helm Chart provides an option to capture and forward FID application metrics and logs to multiple opensource metrics/logging monitoring applications
* The metrics&logging can be enabled by setting "enabled:" to "true" under "metrics:"
* For steps to deploy Prometheus, please refer to the documentation [here](https://artifacthub.io/packages/helm/prometheus-community/prometheus)
* For steps to deploy Grafana, please refer to the documentation [here](https://artifacthub.io/packages/helm/grafana/grafana)


```yaml
metrics:
  enabled: true
  image: radiantone/fid-exporter
  imageTag: latest
  annotations: {}
  pushMode: true
  pushGateway: http://prometheus-server:9091
  pushMetricCron: "* * * * *"

```

* When enabled, the application metrics are collected and forwarded to "Prometheus" an widely used open soure tool for metrics monitoring.
* Also visualization for these metrics is done through "Grafana" another popular tool that is compatible and works with Prometheus.
* When Metrics is enabled, it is assumed that Prometheus and Grafana are already deployed and you will need to provide the "Push Gateway" URL of prometheus push-gateway

```yaml
pushGateway: http://prometheus-server:9091
```

* There is also an option to provide a "CRON" expression to set the frequency at which these metrics are collected and pushed to prometheus.

* By default, this is set to every second

### Logging

* FID Helm chart also provides an option to collect logs from different log files generated by the FID application and forward them to multiple sources like ElasticSearch, OpenSearch, Splunk etc.
* To enable logging, the metrics and fluentd need to be set to "true"
* For steps to deploy Elasticsearch, please refer to the documentation [here](https://artifacthub.io/packages/helm/elastic/elasticsearch)
* For steps to deploy Grafana, please refer to the documentation [here](https://artifacthub.io/packages/helm/elastic/kibana)

```yaml
metrics:
  enabled: true
  image: radiantone/fid-exporter
  imageTag: latest
  annotations: {}
  pushMode: true
  pushGateway: http://prometheus-server:9091
  pushMetricCron: "* * * * *"
  fluentd:
    enabled: true
```

* By default all the major logs have been set to be collected and made available for visualtion through Kibana, Opensearch Dashboards , Splunk etc.

* Each log can be manually enabled/disabled through the values.yaml file.

* It is assumed that one or more of the supported sources is deployed, enabled and the endpoints required are available.

* The logs that needs to be enabled/disabled can be managed here
  * By default the logs will pushed to indexes with names corresponding to "index:" value
  * If a custom_index provided, the default is overwritten
  * The indexes for splunk are created without the ".log" extension to index names
  * Path remains unchanged

```yaml
    logs:
      vds_server:
        enabled: true
        path: "/opt/radiantone/vds/vds_server/logs/vds_server.log"
        index: vds_server.log
        #custom_index:
      vds_events:
        enabled: true
        path: "/opt/radiantone/vds/vds_server/logs/vds_events.log"
        index: vds_events.log
        #custom_index:
```

* The endpoints of the source/sources can be provided under "aggregators:"

```yaml
    aggregators:
      - type: "elasticsearch"
        host: "elastic-host"
        port: "9200"
      - type: "opensearch"
        host: "opensearch-cluster-master"
        port: "9200"
      - type: "splunk_hec"
        hec_hostname: "splunk-s1-standalone-service.splunk-operator.svc.cluster.local"
        hec_port: "8088"
        hec_token: ""

```

> NOTE: Every modification to the aggregators/logs will reload the statefulset.

* Different types of sources required different endpoints.


> For any questions around metrics, please contact support@radiantlogic.com

> NOTE: Currently the supported versions of Prometheus, Grafana, ELasticsearch, Kibana are as follows
> Prometheus - 15.13.0
> Grafana - 6.40.0
> ELasticsearch - 7.17.3
> Kibana - 7.17.3


## **Migration CRON Job**

* FID Helm chart, provides option to create automated backup of FID using regular migration exports
* These exports can be scheduled using CRON expression.
* These exports can be automatically pushed into S3 buckets

```yaml
cronjob:
  migration:
    enabled: false
    schedule: "0 0 * * *"
    s3: "s3://fid-exports/cronjob"

```

## **HELM Hooks**

* Helm hooks are basically kubernetes jobs that can be scheduled before/after installtion, upgrade, delete, rollback etc
* FID Helm chart provides options to enable different hooks that perform different action through running helm jobs.
* There are 8 different helm hooks available, some of which are set to run default jobs, and most of them are configurable according to the use-case.
* To know more about usage Helm Hooks please refer to the documentation [here](https://helm.sh/docs/topics/charts_hooks/)

1. pre-install

2. post-install

3. pre-delete

4. post-delete

5. pre-upgrade

6. post-upgrade

7. pre-rollback

8. post-rollback

* "hooks_sa" is the service account that needs to be enabled for the hook jobs to get required access


```yaml
## Helm Hooks

hooks:
  hooks_sa:
    enabled: false
  pre_install:
    enabled: false
  post_install:
    enabled: false
  pre_upgrade:
    enabled: false
    s3: "s3://fid-exports/pre_ugrade"
  post_upgrade:
    enabled: false
  pre_rollback:
    enabled: false
  post_rollback:
    enabled: false
  pre_delete:
    enabled: false
  post_delete:
    enabled: false

```

* These helm hooks can be used for various purposes, like to install packages before installation of the application itself, to run scripts before delete/rollback e.t.c.


## **Image Credentials**

* Image credentials provide option to create a "imagePullSecret" with the information provided.
* This can be used in situations where private images are involved.
* To know more about usage of image credentials please refer to the documentation [here](https://helm.sh/docs/howto/charts_tips_and_tricks/)

```yaml
# Image Credentials
imageCredentials:
  enabled: false
  registry: docker.io
  username:
  password:
  email:

```


## **Dependencies**

* To know more about HELM Dependencies, refer the documentation [here](https://helm.sh/docs/helm/helm_dependency/)
* FID Helm chart provides an option to deploy the zookeeper helm chart as a dependency chart.
* Using zookeeper as a dependency chart, removes the additional step to deploy zookeeper before deploying FID
* All the values from the values.yaml file of zookeeper can be used based on the requirement

```yaml
# Dependencies are disabled by default.
dependencies:
  zookeeper:
    enabled: false

# Values file Inputs for the dependency charts.
zookeeper:
  fullnameOverride: zookeeper
  replicaCount: 3
  persistence:
    enabled: false
    storageClass: ""

```

* Services in FID helm chart, have been set to automatically recognize, the zookeeper service when available and only then start the FID deployment.
* When downloading the HELM charts or cloning the GIT repo, an additional step to update and build dependencies will be required

```yaml
# Dependency Update

helm dependency update

#Dependency Build

helm dependency build

```

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| <https://radiantlogic-devops.github.io/helm> | zookeeper(zookeeper) | 0.1.4 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.maxReplicas | int | `3` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| cronjob.migration.enabled | bool | `false` |  |
| cronjob.migration.s3 | string | `"s3://fid-exports/cronjob"` |  |
| cronjob.migration.schedule | string | `"0 0 * * *"` |  |
| dependencies.zookeeper.enabled | bool | `false` |  |
| env | object | `{}` |  |
| envFromConfigMaps | list | `[]` |  |
| envFromSecret | string | `""` |  |
| envFromSecrets | list | `[]` |  |
| envRenderSecret | object | `{}` |  |
| envValueFrom | object | `{}` |  |
| extraContainerVolumes | list | `[]` |  |
| extraInitContainers | list | `[]` |  |
| extraVolumeMounts | list | `[]` |  |
| extraVolumes | list | `[]` |  |
| fid.detach | bool | `false` |  |
| fid.followerOnly.detach | bool | `true` |  |
| fid.followerOnly.enabled | bool | `false` |  |
| fid.followerOnly.maxReplicas | int | `3` |  |
| fid.followerOnly.minReplicas | int | `1` |  |
| fid.followerOnly.targetCPUUtilizationPercentage | int | `80` |  |
| fid.license | string | `"[FID Cluster License]"` |  |
| fid.livenessProbe.initialDelaySeconds | int | `60` |  |
| fid.livenessProbe.timeoutSeconds | int | `5` |  |
| fid.migration.script | string | `nil` |  |
| fid.migration.url | string | `nil` |  |
| fid.mountSecrets | bool | `true` |  |
| fid.readinessProbe.initialDelaySeconds | int | `120` |  |
| fid.readinessProbe.timeoutSeconds | int | `5` |  |
| fid.readonly | bool | `false` |  |
| fid.rootPassword | string | `"Welcome1234"` |  |
| fid.rootUser | string | `"cn=Directory Manager"` |  |
| fid.sealedSecrets | bool | `false` |  |
| fullnameOverride | string | `""` |  |
| gateway.enabled | bool | `false` |  |
| gateway.hosts[0] | string | `"chart-example.local"` |  |
| gateway.http.admin.name | string | `"http-admin"` |  |
| gateway.http.admin.port | int | `9100` |  |
| gateway.http.api.name | string | `"http-api"` |  |
| gateway.http.api.port | int | `8089` |  |
| gateway.http.fid.name | string | `"http-fid"` |  |
| gateway.http.fid.port | int | `7070` |  |
| gateway.https.admin.name | string | `"https-admin"` |  |
| gateway.https.admin.port | int | `9101` |  |
| gateway.https.api.name | string | `"https-api"` |  |
| gateway.https.api.port | int | `8090` |  |
| gateway.https.fid.name | string | `"https-fid"` |  |
| gateway.https.fid.port | int | `7171` |  |
| gateway.ldap.name | string | `"ldap"` |  |
| gateway.ldap.port | int | `2389` |  |
| gateway.ldaps.name | string | `"ldaps"` |  |
| gateway.ldaps.port | int | `2636` |  |
| hooks.hooks_sa.enabled | bool | `false` |  |
| hooks.post_delete.enabled | bool | `false` |  |
| hooks.post_install.enabled | bool | `false` |  |
| hooks.post_rollback.enabled | bool | `false` |  |
| hooks.post_upgrade.enabled | bool | `false` |  |
| hooks.pre_delete.enabled | bool | `false` |  |
| hooks.pre_install.enabled | bool | `false` |  |
| hooks.pre_rollback.enabled | bool | `false` |  |
| hooks.pre_upgrade.enabled | bool | `false` |  |
| hooks.pre_upgrade.s3 | string | `"s3://fid-exports/pre_ugrade"` |  |
| image.pullPolicy | string | `"Always"` |  |
| image.repository | string | `"radiantone/fid"` |  |
| image.tag | string | `""` |  |
| imageCredentials.email | string | `nil` |  |
| imageCredentials.enabled | bool | `false` |  |
| imageCredentials.password | string | `nil` |  |
| imageCredentials.registry | string | `"docker.io"` |  |
| imageCredentials.username | string | `nil` |  |
| imagePullSecrets | list | `[]` |  |
| ingress.annotations."kubernetes.io/ingress.class" | string | `"nginx"` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"chart-example.local"` |  |
| ingress.hosts[0].paths[0] | string | `"/"` |  |
| ingress.tls | list | `[]` |  |
| kibanadashboard.enabled | bool | `false` |  |
| kibanadashboard.kibanaURL | string | `"<kibana-service-name>.<namespace>.svc.cluster.local:<kibana-port>"` |  |
| metrics.annotations | object | `{}` |  |
| metrics.enabled | bool | `true` |  |
| metrics.fluentd.aggregators[0].host | string | `"elastic-host"` |  |
| metrics.fluentd.aggregators[0].port | string | `"9200"` |  |
| metrics.fluentd.aggregators[0].type | string | `"elasticsearch"` |  |
| metrics.fluentd.configFile | string | `"/fluentd/etc/fluent.conf"` |  |
| metrics.fluentd.enabled | bool | `true` |  |
| metrics.fluentd.logs.adap_access.enabled | bool | `true` |  |
| metrics.fluentd.logs.adap_access.index | string | `"adap_access.log"` |  |
| metrics.fluentd.logs.adap_access.path | string | `"/opt/radiantone/vds/vds_server/logs/adap_access.log"` |  |
| metrics.fluentd.logs.admin_rest_api_access.enabled | bool | `true` |  |
| metrics.fluentd.logs.admin_rest_api_access.index | string | `"admin_rest_api_access.log"` |  |
| metrics.fluentd.logs.admin_rest_api_access.path | string | `"/opt/radiantone/vds/vds_server/logs/admin_rest_api_access.log"` |  |
| metrics.fluentd.logs.alerts.enabled | bool | `true` |  |
| metrics.fluentd.logs.alerts.index | string | `"alerts.log"` |  |
| metrics.fluentd.logs.alerts.path | string | `"/opt/radiantone/vds/vds_server/logs/alerts.log"` |  |
| metrics.fluentd.logs.periodiccache.enabled | bool | `true` |  |
| metrics.fluentd.logs.periodiccache.index | string | `"periodiccache.log"` |  |
| metrics.fluentd.logs.periodiccache.path | string | `"/opt/radiantone/vds/vds_server/logs/periodiccache.log"` |  |
| metrics.fluentd.logs.sync_engine.enabled | bool | `true` |  |
| metrics.fluentd.logs.sync_engine.index | string | `"sync_engine.log"` |  |
| metrics.fluentd.logs.sync_engine.path | string | `"/opt/radiantone/vds/vds_server/logs/sync_engine.log"` |  |
| metrics.fluentd.logs.vds_events.enabled | bool | `true` |  |
| metrics.fluentd.logs.vds_events.index | string | `"vds_events.log"` |  |
| metrics.fluentd.logs.vds_events.path | string | `"/opt/radiantone/vds/vds_server/logs/vds_events.log"` |  |
| metrics.fluentd.logs.vds_server.enabled | bool | `true` |  |
| metrics.fluentd.logs.vds_server.index | string | `"vds_server.log"` |  |
| metrics.fluentd.logs.vds_server.path | string | `"/opt/radiantone/vds/vds_server/logs/vds_server.log"` |  |
| metrics.fluentd.logs.vds_server_access.enabled | bool | `true` |  |
| metrics.fluentd.logs.vds_server_access.index | string | `"vds_server_access.log"` |  |
| metrics.fluentd.logs.vds_server_access.parse | string | `"<parse>\n  @type tsv\n  keys LOGID,LOGDATE,LOGTIME,LOGTYPE,SERVERID,SERVERPORT,SESSIONID,MSGID,CLIENTIP,BINDDN,BINDUSER,CONNNB,OPNB,OPCODE,OPNAME,BASEDN,ATTRIBUTES,SCOPE,FILTER,SIZELIMIT,TIMELIMIT,LDAPCONTROLS,CHANGES,RESULTCODE,ERRORMESSAGE,MATCHEDDN,NBENTRIES,ETIME\n  types LOGID:integer,LOGDATE:string,LOGTIME:string,LOGTYPE:integer,SERVERID:string,SERVERPORT:integer,SESSIONID:integer,MSGID:integer,CLIENTIP:string,BINDDN:string,BINDUSER:string,CONNNB:integer,OPNB:integer,OPCODE:integer,OPNAME:string,BASEDN:string,ATTRIBUTES:string,SCOPE:string,FILTER:string,SIZELIMIT:integer,TIMELIMIT:integer,LDAPCONTROLS:string,CHANGES:string,RESULTCODE:integer,ERRORMESSAGE:string,MATCHEDDN:string,NBENTRIES:integer,ETIME:integer\n</parse>"` |  |
| metrics.fluentd.logs.vds_server_access.path | string | `"/opt/radiantone/vds/vds_server/logs/vds_server_access.log"` |  |
| metrics.fluentd.logs.web.enabled | bool | `true` |  |
| metrics.fluentd.logs.web.index | string | `"web.log"` |  |
| metrics.fluentd.logs.web.path | string | `"/opt/radiantone/vds/vds_server/logs/web.log"` |  |
| metrics.fluentd.logs.web_access.enabled | bool | `true` |  |
| metrics.fluentd.logs.web_access.index | string | `"web_access.log"` |  |
| metrics.fluentd.logs.web_access.path | string | `"/opt/radiantone/vds/vds_server/logs/web_access.log"` |  |
| metrics.image | string | `"radiantone/fid-exporter"` |  |
| metrics.imageTag | string | `"latest"` |  |
| metrics.livenessProbe.initialDelaySeconds | int | `60` |  |
| metrics.livenessProbe.timeoutSeconds | int | `5` |  |
| metrics.pushGateway | string | `"http://prometheus-server:9091"` |  |
| metrics.pushMetricCron | string | `"* * * * *"` |  |
| metrics.pushMode | bool | `true` |  |
| metrics.readinessProbe.initialDelaySeconds | int | `120` |  |
| metrics.readinessProbe.timeoutSeconds | int | `5` |  |
| nameOverride | string | `""` |  |
| nodeSelector | object | `{}` |  |
| persistence.accessModes[0] | string | `"ReadWriteOnce"` |  |
| persistence.annotations | object | `{}` |  |
| persistence.enabled | bool | `false` |  |
| persistence.size | string | `"10Gi"` |  |
| persistence.storageClass | string | `"default"` |  |
| podAnnotations | object | `{}` |  |
| podSecurityContext.fsGroup | int | `1000` |  |
| postInstall.enabled | bool | `false` |  |
| postInstall.leaderOnly | bool | `true` |  |
| postInstall.script | string | `"# Post install custom script\n"` |  |
| postStart.enabled | bool | `false` |  |
| postStart.leaderOnly | bool | `true` |  |
| postStart.script | string | `"# Post install custom script\n"` |  |
| replicaCount | int | `1` |  |
| resources.limits.cpu | int | `1` |  |
| resources.limits.memory | string | `"2Gi"` |  |
| resources.requests.cpu | string | `"500m"` |  |
| resources.requests.memory | string | `"1Gi"` |  |
| securityContext | object | `{}` |  |
| service.port | int | `7070` |  |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.create | bool | `false` |  |
| serviceAccount.name | string | `""` |  |
| sidecars | list | `[]` |  |
| sysctl.enabled | bool | `false` |  |
| tolerations | list | `[]` |  |
| zk.clusterName | string | `"fid-cluster"` |  |
| zk.connectionString | string | `"zookeeper-app:2181"` |  |
| zk.external | bool | `true` |  |
| zk.password | string | `"secret1234"` |  |
| zk.ruok | string | `"http://zookeeper-app:8080/commands/ruok"` |  |
| zk.userName | string | `"admin"` |  |
| zookeeper.fullnameOverride | string | `"zookeeper"` |  |
| zookeeper.persistence.enabled | bool | `false` |  |
| zookeeper.persistence.storageClass | string | `""` |  |
| zookeeper.replicaCount | int | `3` |  |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| pgodey | <pgodey@radiantlogic.com> | <https://www.radiantlogic.com> |
