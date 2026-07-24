# 01 — Getting started

## Minimum viable install

```bash
helm repo add radiantone https://radiantlogic-devops.github.io/helm
helm install fid radiantone/fid -n my-namespace -f values.yaml
```

```yaml
# values.yaml — smallest thing that actually works
replicaCount: 2

image:
  repository: radiantone/fid
  tag: "7.4.23"          # pin it; see the warning below

fid:
  license: "{rlib}...your license..."
  rootPassword: "change-me"
  mountSecrets: false    # REQUIRED for any 7.x image

persistence:
  enabled: true
  storageClass: "auto"   # or an explicit class name

dependencies:
  zookeeper:
    enabled: true        # bundle ZooKeeper; omit if you have an external ensemble
```

## Two settings that cause most first-install failures

### `image.tag` must be set

`Chart.yaml` declares `appVersion: 8.0.4`, so an **unpinned tag pulls an 8.x image** even
though this is the v7 chart line. Always pin.

### `fid.mountSecrets: false` for 7.x

The chart default is `true`, which delivers credentials as *mounted files*. Only FID 8.0.0+
can read those. A 7.x image starts, finds no credentials, and never becomes ready — with
nothing useful in the events.

The chart now catches this for you:

```
PREFLIGHT: fid.mountSecrets is true but image tag "7.4.23" is older than 8.0.0.
Fix:      set  fid.mountSecrets: false
Bypass:   set  preflight.mountSecretsVersionCheck: false
```

## Verifying an install

```bash
helm test fid -n my-namespace          # four bundled suites
kubectl -n my-namespace exec fid-0 -c fid -- /opt/radiantone/vds/bin/show_version.sh
```

## Things that are different on a 7.x image

Useful when debugging; these are image differences, not chart behaviour:

- **no `ldapsearch`** under `/opt/radiantone/vds/bin/advanced/` (8.x ships it)
- **no `python3`**
- `zkCli.sh` is at `/opt/radiantone/vds/apps/zookeeper/bin/` and needs
  `JAVA_HOME=/opt/radiantone/vds/jdk/jre`; even then the cluster znodes are ACL-protected
  and return `Authentication is not valid` — expected, not a fault

Prefer `helm test` over hand-rolled LDAP probes.

## Multi-tenant clusters (Duplo)

Per-tenant security groups block cross-tenant pod traffic, so **FID and ZooKeeper must land
on the same tenant's nodes**:

```yaml
nodeSelector:
  tenantname: "duploservices-mytenant"
zookeeper:
  nodeSelector:
    tenantname: "duploservices-mytenant"
  persistence:
    storageClass: "duploservices-mytenant-encrypted-gp3"
```

Split them and FID's `check-zk` init container loops forever on `zookeeper-app:2181`.

## Timeline to expect

On a cluster whose node group is scaled to zero, budget ~10 minutes:

| t | event |
|---|---|
| 0:00 | `helm install` returns; pods Pending |
| ~0:45 | cluster-autoscaler adds a node |
| ~2:30 | ZooKeeper quorum forms |
| ~4:00 | FID listening on 2389/2636 |
| ~6:00 | fid-0 Ready (gated by `readinessProbe.initialDelaySeconds: 120`) |
| ~10:00 | fid-1 Ready |
