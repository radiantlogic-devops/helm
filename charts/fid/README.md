# helm
Helm chart for FID deployment

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
