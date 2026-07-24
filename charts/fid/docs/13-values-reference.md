# 13 — Values reference

Every top-level key, grouped by purpose. `values.yaml` itself carries the detailed inline
comments; this is the map.

## Core

| Key | Default | Purpose |
|---|---|---|
| `replicaCount` | `1` | FID StatefulSet replicas |
| `image` | `radiantone/fid`, tag `""` | Main FID image. **Pin the tag** — unset resolves to appVersion `8.0.4` |
| `imagePullSecrets` | `[]` | Merged with `global.imagePullSecrets` |
| `nameOverride` / `fullnameOverride` | `""` | Naming |
| `resources` | 1cpu/2Gi limits | FID container resources |
| `nodeSelector` / `tolerations` / `affinity` | `{}` / `[]` / `{}` | Scheduling |
| `updateStrategy` | `RollingUpdate` | StatefulSet update strategy |
| `service` | `ClusterIP` | Service type and Control Panel port |

## Global and metadata

| Key | Default | Purpose |
|---|---|---|
| `global.imageRegistry` | `""` | Registry prefix for **every** image. The airgap switch |
| `global.imagePullSecrets` | `[]` | Pull secrets added to every pod |
| `commonLabels` | `{}` | Labels on all 29 rendered objects |
| `commonAnnotations` | `{}` | Annotations on all rendered objects |

## FID application

| Key | Default | Purpose |
|---|---|---|
| `fid.rootUser` | `cn=Directory Manager` | Root DN |
| `fid.rootPassword` | `Welcome1234` | **Change this** |
| `fid.license` | placeholder | Cluster license |
| `fid.mountSecrets` | `true` | **Set false for any 7.x image** |
| `fid.existingSecret` | `""` | Bring your own Secret; chart renders none |
| `fid.retainSecret` | `false` | `resource-policy: keep` on the Secret |
| `fid.detach` | `false` | Detach from cluster on termination |
| `fid.readonly` | `false` | Join an existing cluster read-only |
| `fid.followerOnly` | `enabled: false` | Follower-only StatefulSet + autoscaling |
| `fid.livenessProbe` / `readinessProbe` | see [09](09-probes-and-availability.md) | All fields tunable |
| `fid.startupProbe` | `enabled: false` | Long startup grace without weakening liveness |
| `fid.migration` | `url: null` | See [08](08-migration.md) |
| `fid.podSpecPatch` | unset | **The no-ceiling escape hatch** |

## ZooKeeper

| Key | Default | Purpose |
|---|---|---|
| `zk.external` | `true` | Use an external ensemble |
| `zk.connectionString` | `zookeeper-app:2181` | |
| `zk.clusterName` | `fid-cluster` | ZK path; change it to run two FID clusters on one ensemble |
| `zk.userName` / `zk.password` | `admin` / `secret1234` | **Change the password** |
| `dependencies.zookeeper.enabled` | `false` | Bundle the ZooKeeper subchart |
| `zookeeper.*` | | Values passed to that subchart |

## Security

| Key | Default | Purpose |
|---|---|---|
| `security.profile` | `vanilla` | `vanilla`\|`baseline`\|`hardened`\|`paranoid`\|`custom` |
| `podSecurityContext` | `fsGroup: 1000` | Merged over the profile |
| `securityContext` | `{}` | FID container; merged over the profile |
| `helperSecurityContext` | `{}` | Init/helper containers |
| `automountServiceAccountToken` | unset | Profile sets `false` on hardened/paranoid |
| `networkPolicy` | follows profile | Tri-state `enabled` |
| `hooks.rbac.rules` | `[]` | Replaces the default hook Role entirely |
| `serviceAccount` | `create: true` | |

## Images

| Key | Default | Purpose |
|---|---|---|
| `helperImages.checkZk` | `radiantone/init-tools:latest` | ZK TCP wait (`nc`) |
| `helperImages.checkZkReadonly` | `radiantone/curl:latest` | ZK writable wait |
| `helperImages.checkFid` | `radiantone/init-tools:latest` | Follower's leader wait |
| `helperImages.sysctl` | `busybox:latest` | `vm.max_map_count` (privileged) |
| `helperImages.migration` | `radiantone/curl:latest` | Legacy migration fetch |
| `helperImages.hooks` | `radiantone/kubectl:latest` | Hook Jobs + migration CronJob |
| `helperImages.testCurl` / `testBusybox` | `radiantone/curl` / `busybox` | `helm test` pods |
| `helperResources` | 100m/128Mi | Fallback for helper containers |
| `hookResources` | `{}` | **Set under a LimitRange/ResourceQuota** |

## Storage

| Key | Default | Purpose |
|---|---|---|
| `persistence.enabled` | `false` | |
| `persistence.storageClass` | `"default"` | `auto` \| `-` \| `""` \| name — see [06](06-storage.md) |
| `persistence.size` | `10Gi` | **Immutable after install** |
| `persistence.accessModes` | `[ReadWriteOnce]` | |
| `persistence.annotations` | `{}` | |

## Networking

| Key | Default | Purpose |
|---|---|---|
| `networking.hostname` | `""` | Required when any controller is enabled |
| `networking.extraHostnames` | `[]` | |
| `networking.tls` | `enabled: false` | |
| `networking.routes` | controlPanel on | Shared by all three controllers; expandable |
| `networking.ldaps` / `ldap` | `enabled: false` | TCP 636→2636 / 389→2389 |
| `networking.nginx` / `traefik` / `istio` | `enabled: false` | See [05](05-ingress.md) |
| `ingress` / `gateway` / `virtualservice` | `enabled: false` | **Legacy**, still supported |

## Metrics and logging

| Key | Default | Purpose |
|---|---|---|
| `metrics.enabled` | `false` | Exporter + Fluentd sidecar |
| `metrics.flavor` | `fid-exporter` | or `rl-exporter` |
| `metrics.imageRepository` / `tag` | `radiantone/fid-exporter` / `iddm-8.4.5` | |
| `metrics.pushMode` | `true` | **Required for fid-exporter to export at all** |
| `metrics.pushGateway` | `http://prometheus-server:9091` | |
| `metrics.resources` | 1cpu/1Gi | **Raise on OOM** |
| `metrics.securityContext` | `runAsUser: 0` | Needs root to read logs |
| `metrics.fluentd.enabled` | `false` | |
| `metrics.fluentd.aggregators` | | elasticsearch \| opensearch \| splunk_hec |
| `metrics.fluentd.logs.*` | 9 FID logs | Per-log enable/path/index |

## Secrets

| Key | Default | Purpose |
|---|---|---|
| `externalSecret.enabled` | `false` | ESO integration |
| `externalSecret.secretStoreRef` | | Required when enabled |
| `externalSecret.remoteKey` | | Simple single-secret form |
| `externalSecret.data` / `dataFrom` | | Explicit mapping |
| `sealedSecrets` / `fid.sealedSecrets` | `false` | Suppress the chart's Secret |

## Availability

| Key | Default | Purpose |
|---|---|---|
| `podDisruptionBudget.enabled` | `true` | |
| `podDisruptionBudget.maxUnavailable` | `1` | |
| `podDisruptionBudget.minAvailable` | unset | Use instead of maxUnavailable |
| `autoscaling` | `enabled: false` | HPA for the main STS |

## Lifecycle

| Key | Default | Purpose |
|---|---|---|
| `hooks.hooks_sa.enabled` | `false` | Hook ServiceAccount + scoped RBAC |
| `hooks.{pre,post}_{install,upgrade,delete,rollback}` | `false` | All eight are no-ops by default |
| `cronjob.migration` | `enabled: false` | Scheduled export |
| `postStart` | `enabled: false` | postStart script |

## Safety

| Key | Default | Purpose |
|---|---|---|
| `preflight.mountSecretsVersionCheck` | `true` | 7.x + mountSecrets |
| `preflight.immutableFieldCheck` | `true` | selector / volumeClaimTemplate drift |
| `preflight.storageClassCheck` | `true` | Non-existent StorageClass |

## Escape hatches

| Key | Default |
|---|---|
| `extraInitContainers`, `extraContainers`, `sidecars` | `[]` |
| `extraVolumes`, `extraVolumeMounts`, `extraContainerVolumes` | `[]` |
| `extraObjects` | `[]` |
| `env`, `envValueFrom`, `envFromSecret`, `envFromSecrets`, `envFromConfigMaps`, `envRenderSecret` | `{}` / `""` / `[]` |
| `fid.podSpecPatch` | unset |

## Schema validation

`values.schema.json` validates the **shape** of known keys — enums, types, digest format —
and catches typos early. `additionalProperties` is `true` everywhere by design: unknown and
future keys always pass, so the schema can never block you.

```bash
helm lint charts/fid -f my-values.yaml
```
