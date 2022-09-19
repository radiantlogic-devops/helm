# helm
Helm chart for Zookeeper deployment

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

## TL;DR

```console
$ helm repo add radiantone https://radiantlogic-devops.github.io/helm
$ helm install my-zk-release radiantone/zookeeper
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
