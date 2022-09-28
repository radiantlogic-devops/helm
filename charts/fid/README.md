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


## Hooks 

* Helm Hooks have been added to allow intervention at certain point (install, upgrade, rollback and delete) of lifecycle
* These hooks can be found under hooks folder in the templates.
* Avaibalbe hooks are pre/post-Install, Upgrade, Rollback and Delete
* A service account with permissions to perform actions required by helm hooks can also be created by enabling(hooks-sa.yaml)
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



