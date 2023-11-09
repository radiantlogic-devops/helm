# Deploying FID 7.4.x On-Prem

## Pre-Requisites

1. HELM 3
2. Kubernetes 1.18+
3. FID License 

## Add Helm Repository

```yaml
helm repo add radiantone https://radiantlogic-devops.github.io/helm
```

### Update helm repositories

Update gets the latest information about charts from the respective chart repositories, if you already have the charts added

```yaml
helm repo update
```

## DEPLOY FID WITH ZOOKEEPER AS A DEPENDENCY

- Zookeeper can deployed as [dependency](https://helm.sh/docs/helm/helm_dependency/) chart to FID
- Any modifications to the values.yaml of the zookeeper, can also done through the FID’s values.yaml file
- The dependencies section of the values.yaml file (fid) should be modified in the following way

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

- Additional Values of [zookeeper](https://github.com/radiantlogic-devops/helm/blob/master/charts/zookeeper/values.yaml) can be included in the above.

Commands:

Update the HELM Dependencies 

- If you are deploying the FID by downloading (or cloning) the FID helm chart you will need to run the command below manually

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

## DEPLOYING ZOOKEEPER AND FID INDIVIDUALLY

## Deploying Zookeeper

- FID needs Zookeeper to be deployed ahead of its deployment
- You can find the Zookeeper chart repository [here](https://github.com/radiantlogic-devops/helm/tree/master/charts/zookeeper)
- Zookeeper is a [statefulsets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) type deployment and requires [PVC](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) in order to maintain its state
- The PVCs for zookeeper are dynamically created based on the type and size provided during the deployment
- Official Radiantone Zookeeper docker images can be found [here](https://hub.docker.com/r/radiantone/zookeeper)
- For better performance and high availability , it is recommended to run Zookeeper as an external type and the documentation covers external-zookeeper installation only

```yaml
helm install --namespace=<name space> <release name> radiantone/zookeeper
```

### **Sample Values File to deploy Zookeeper with overridden values**

[https://helm.sh/docs/helm/helm_install/](https://helm.sh/docs/helm/helm_install/)

- Values files can be used to override any default values during the deployment
- The sample values file below can be modified according to the usage and be used to deploy zookeeper

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

- The HELM chart repository for FID can be found [here](https://github.com/radiantlogic-devops/helm/tree/master/charts/fid)
- FID is a [statefulset](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) type deployment and will require PVC to maintain its state
- FID is dependent on Zookeeper
- The official docker images for [FID](https://hub.docker.com/r/radiantone/fid) can be found here
- FID has built in checks that check if
    - Zookeeper is writable
    - Zookeeper is reachable

**DEPLOYING FID WITH DEFAULT VALUES**

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

**DEPLOYING USING THE VALUES.YAML FILE**

- FID has extensive list of modifications available through the [values.yaml](https://github.com/radiantlogic-devops/helm/blob/master/charts/fid/values.yaml) file.

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
resources:
  limits:
    cpu: 1
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi

```

**DEPLOYING FID 7.4.x using the values.yaml file**

- FID is deployed with version 7.4.x
- Persistence is enabled
- Choose a storageClass based on the cloud provider (example: gp2/gp3 for AWS)
- A valid FID license will be required

```yaml
replicaCount: 1
image:
  repository: radiantone/fid
  tag: "7.4.x"
fid:
  rootUser: "cn=Directory Manager"
  rootPassword: "Welcome1234"
  license: "[FID Cluster License]"
persistence:
  enabled: true
  storageClass: "default"
  accessModes:
  - ReadWriteOnce
  size: 10Gi
  annotations: {}

```

Command:

```yaml
helm -n <namespace> install <release name> radiantone/fid --values <path to the values file>
```