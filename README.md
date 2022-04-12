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
