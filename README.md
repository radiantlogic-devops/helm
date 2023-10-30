# helm
Helm charts for RadiantOne FID deployment

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

### TL;DR

```
$ helm repo add radiantone https://radiantlogic-devops.github.io/helm
$ helm install my-fid-release radiantone/fid --set fid.license=<license> \
--set dependencies.zookeeper.enabled=true --set image.tag=7.4 --set fid.mountSectes=false
```
** Only 7.3.x and 7.4.x versions are supported for Helm deployments

### Add Helm repo

Once Helm has been set up correctly, add the repo as follows:

```
helm repo add radiantone https://radiantlogic-devops.github.io/helm
```

To update a repository that has already been added, run `helm repo update` to retrieve the latest versions of the packages.

To see the charts in the radiantone repository, run `helm search repo radiantone`

### Charts

### Prerequisites
* Kubernetes 1.18+
* Helm 3

### Setup
#### Installation
* Install RadiantOne FID version 7.4 (latest)
```
helm upgrade --install --namespace=<name space> <release name> radiantone/fid \
--set dependencies.zookeeper.enabled=true
--set zk.clusterName=my-demo-cluster \
--set fid.license="<FID cluster license>" \
--set fid.rootPassword="test1234" \
--set fid.mountSecrets=false \
--set image.tag=7.4
```
Note: Curly brackets in the license must be escaped ```--set fid.license="\{rlib\}xxx"```

#### List
* List FID releases
```
helm list --namespace=<name space>
```

#### Test
* Test FID release
```
helm test <release name> --namespace=<name space>
```

#### Upgrade
* Upgrade FID release
* Note: Upgrade can only be performed to a higher version
* Note: Upgrade from 7.3.x to 7.4.x is not supported
```
helm upgrade --install --namespace=<name space> <release name> radiantone/fid --reuse-values
```

### Clean Up
* Delete FID release
* Note: Does not delete the persistent volumes
```
helm uninstall --namespace=<name space> <release name>
```

#### Remove Helm repo

```
helm repo remove radiantone
```
