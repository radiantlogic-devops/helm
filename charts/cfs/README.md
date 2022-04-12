
# helm

Helm charts for CFS deployment

[Helm](https://helm.sh/) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

> Important Note: Deploying CFS requires windows worker nodes to be present in the Kubernetes cluster, prior to the deployment.
>

## Add helm repo

Once Helm has been setup, add the repo as follows, if not added already.

```console
helm repo add radiantone https://radiantlogic-devops.github.io/helm
```

If repository is already present, run the following command to retrieve the latest version of the package

```console
helm repo update
```

## Install CFS

### Prerequisites

- Kubernetes 1.18+
- Helm 3
- FID Installed and running
- Windows worker-nodes in Kubernetes

### Charts

### Install CFS

- Install CFS with default values

```console
helm install --namespace=<name space> <release name> radiantone/cfs
```

> Note: Generate machine-key before running the helm install command using the command below
>

- Generate machine key

```powershell
./GenerateMachineKey.ps1 encode=True
```

- Install CFS with overidden values

```bash
helm install --namespace=<name space> <release name> radiantone/cfs \
--set cfs.machineKey="<machine-key>" --set fid.hostName="<fid-hostname>" \
--set fid.password="<directory manager password>"
```
