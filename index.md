# helm
Helm charts for FID deployment

## Add Helm repo
### TODO

## Remove Helm repo
### TODO

## Install Zookeeper

### Prerequisites
* Kubernetes 1.18+
* Helm 3

### Charts
* Clone repo
```
git clone https://github.com/radiantlogic-devops/helm.git
```
* Install ZK
Install Zookeeper with default values
```
helm install --namespace=<name space> <release name> zookeeper
```
Install Zookeeper with overridden values
```
helm install --namespace=<name space> <release name> zookeeper \
--set replicaCount="5"
```
* List ZK releases
```
helm list --namespace=<name space>
```
* Upgrade ZK release
```
helm upgrade --namespace=<name space> <release name> zookeeper
```
* Delete ZK release
```
helm delete --namespace=<name space> <release name>
```

## Install FID

### Prerequisites
* Kubernetes 1.18+
* Helm 3

### Charts
* Clone repo
```
git clone https://github.com/radiantlogic-devops/helm.git
```
Install FID with default values
```
helm install --namespace=<name space> <release name> fid
```
Install FID with overridden values
```
helm install --namespace=<name space> <release name> fid \
--set zk.connectionString="zk.dev:2181" \
--set zk.ruok="http://zk.dev:8080/commands/ruok" \
--set fid.license="<FID cluster license>" \
--set fid.rootPassword="test1234"
```
* List FID releases
```
helm list --namespace=<name space>
```
* Upgrade FID release
```
helm upgrade --namespace=<name space> <release name> fid
```
* Delete FID release
```
helm delete --namespace=<name space> <release name>
```
