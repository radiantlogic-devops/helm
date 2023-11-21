# helm
Helm charts for RadiantOne FID deployment

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

---
### TL;DR

```console
helm repo add radiantone https://radiantlogic-devops.github.io/helm
helm install my-fid-release radiantone/fid --set fid.license=<license> \
--set dependencies.zookeeper.enabled=true --set image.tag=7.4 --set fid.mountSecrets=false
```
**NOTE**
* Only 7.3.x and 7.4.x versions are supported for Helm deployments

---
### Add Helm repo

Once Helm has been set up correctly, add the repo as follows:

```console
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
##### Install RadiantOne FID version 7.4 (latest) using helm --set values
```console
helm upgrade --install --namespace=<name space> <release name> radiantone/fid \
--set dependencies.zookeeper.enabled=true
--set zk.clusterName=my-demo-cluster \
--set fid.license="<license key>" \
--set fid.rootPassword="test1234" \
--set fid.mountSecrets=false \
--set image.tag=7.4
```
---
**NOTE**
* Curly brackets in the license must be escaped --set fid.license="\{rlib\}xxx"

---

##### Install RadiantOne FID version 7.4 (latest) using helm values file.

Create a file with these contents and save it as fid_values.yaml
  
```yaml
image:
  tag: "7.4"
fid:
  rootPassword: "test1234"
  license: "<license key>"
  mountSecrets: false
zk:
  cluserName: "my-demo-cluster"
dependencies:
  zookeeper:
    enabled: true
```
Run this command
```console
helm upgrade --install --namespace=<name space> <release name> radiantone/fid --values fid_values.yaml
```

##### Install RadiantOne FID version 7.4 (latest) using Argo CD.

For installation using CD tool like Argo CD see this link - https://github.com/radiantlogic-devops/radiantone-argocd-helm

#### List
##### List FID releases
```console
helm list --namespace=<name space>
```

#### Test
##### Test FID release
```console
helm test <release name> --namespace=<name space>
```

#### Upgrade
##### Upgrade FID release
---
**NOTE**
* Upgrade can only be performed to a higher version
* Upgrade from 7.3.x to 7.4.x is not supported

---

* Using --set values - set image.tag value
```console
helm upgrade --install --namespace=<name space> <release name> radiantone/fid --set image.tag=7.4.8 --reuse-values
```
* Using values file - update the values file with the newer version tag.
```yaml
image:
  tag: "7.4"
fid:
  rootPassword: "test1234"
  license: "<license key>"
  mountSecrets: false
zk:
  cluserName: "my-demo-cluster"
dependencies:
  zookeeper:
    enabled: true
```

```console
helm upgrade --install --namespace=<name space> <release name> radiantone/fid --values fid_values.yaml --reuse-values
```

### Clean Up
* Delete FID release

---
**NOTE**
* Note: Does not delete the persistent volumes

---
```console
helm uninstall --namespace=<name space> <release name>
```

#### Remove Helm repo

```console
helm repo remove radiantone
```
