# helm
Helm charts for FID deployment

## Add Helm repo
### TODO

## Remove Helm repo
### TODO

## Install FID

### Prerequisites
* Kubernetes 1.16+
* Helm 3

### Charts
* Clone repo
```
git clone https://github.com/radiantlogic-devops/helm.git
```
* Install ZK
### TODO

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
