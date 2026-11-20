# Changelog

All notable changes to this Helm repository are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [common-services 2.0.4] — unreleased

### Scope

A small maintenance release on top of **common-services 2.0.3**. Existing environment `values.yaml` files
need no change: every change is in the chart's dependencies and defaults.

| Component | 2.0.3 | 2.0.4 |
|---|---|---|
| Grafana chart | `8.10.0` (`grafana.github.io`) | `11.6.1` (`grafana-community.github.io`) |
| Grafana application | `11.5.1` (chart default) | `11.5.1` (pinned in `values.yaml`) |
| Grafana dashboard sidecar | `1.30.0` | `2.6.0` |
| Grafana rollout | `RollingUpdate` | `Recreate` |
| Elasticsearch | `7.17.25` | `7.17.29` |
| Kibana | `7.17.25` | `7.17.29` |
| Curator | 24 log prefixes | 25 (adds `connector.log`) |

### Grafana

- The grafana chart moved from `grafana.github.io` to `grafana-community.github.io`; the dependency now points
  at chart `11.6.1` there.
- `grafana.image.tag` is pinned to `11.5.1`, the application version the previous chart shipped, so the chart
  upgrade alone does not change Grafana. Environments that already set `grafana.image.tag` keep their value.
- `grafana.deploymentStrategy.type` is now `Recreate`. Grafana keeps its data on one ReadWriteOnce volume; with
  a rolling update the new pod can be scheduled on a different node while the old pod still holds the volume,
  and the rollout then waits forever. `Recreate` stops the old pod first, at the cost of a short Grafana
  outage during an upgrade.
- The chart's `grafana-test` test Pod, ConfigMap and ServiceAccount are no longer rendered.

### Elasticsearch and Kibana

- `elasticsearch.imageTag` and `kibana.imageTag` move from `7.17.25` to `7.17.29`, the latest 7.17 patch. The
  charts stay at `7.17.3`. Elasticsearch restarts as a rolling update; data stays on the same volume.

### Curator: `connector.log` retention

- Adds `- name: "connector.log"` to `curator.logs`, after `sync_engine.log`. The fid-exporter ships this index
  but Curator had no action for it, so its daily indices were never deleted. It inherits the chart defaults
  (`delete_indices`, older than 7 days), the same as the other prefixes.
- `curator.logs` is a list, so an environment that overrides the list does not inherit the new entry.
- The first Curator run after the upgrade deletes the whole backlog for that prefix.

### Dashboards

- IDDM dashboards: the node memory tile no longer shows red on healthy nodes.

### Rendered difference from 2.0.3

Rendered with an existing environment values file, the manifests differ in the `grafana` Deployment, Service
and ConfigMap, the `kibana` Deployment, the `elasticsearch-master` StatefulSet, the `curator-config` ConfigMap
and the two IDDM dashboard ConfigMaps. No selector changes, no volume changes.

## [common-services 2.0.3] — 2026-07-24

### Scope

Version bump and Ops hardening of **common-services 2.0.3** for **Kubernetes 1.34 / 1.35** clusters:

| Domain | Components |
|---|---|
| Backup / DR | Velero |
| Databases | CloudNativePG |
| Data processing | Flink Kubernetes Operator |
| Observability / logs | Alloy, Loki |
| Removal | Nebula Operator (complete) |

Delivery via **Argo CD**: **a single final Git state** `common-services` **2.0.3**, **one sync** to that state. No intermediate Helm steps, no RC, no multi-sync migration runner.

### Version table (current → target)

| Component | Current chart | Current app | Target chart | Target app |
|---|---|---|---|---|
| Velero | `10.1.2` | `1.16.2` | `12.2.0` | `1.18.2` |
| CloudNativePG | `0.28.3` | `1.29.1` | `0.29.1` | `1.30.1` |
| Flink Kubernetes Operator | `1.14.0` | `1.14.0` | `1.15.0` | `1.15.0` |
| Alloy | `1.2.1` | `v1.10.1` | `1.13.0` | `v1.20.0` |
| Loki | `grafana/loki` `6.40.0` | `3.5.3` | `grafana-community/loki` `18.13.7` | `3.7.8` |
| Nebula Operator | `1.8.6` | — | **removed** | — |

Flink repository updated to `https://downloads.apache.org/flink/flink-kubernetes-operator-1.15.0`.

### Delivery decisions

- **A single final Git state 2.0.3**, one Argo CD sync.
- **No Helm steps / RC / multi-sync runner** for Velero or Loki.
- Velero rationale: official documentation is structured version-by-version; with the **final CRDs** applied by `crds-installer` and the target Velero image / AWS plugin, a direct 1.16 → 1.18 cut is acceptable for Ops (no need to deploy 1.17 as an intermediate step in this repository).
- Loki rationale: the Grafana Community guide describes a **`helm upgrade`** after adapting values, not a chain of twelve intermediate deployments. Local values are corrected so they are consistent with S3 + SimpleScalable before the cut.

### Why the Loki Helm repository changes

- The OSS Loki Helm chart moved to **Grafana Community**.
- On the old repository `https://grafana.github.io/helm-charts`, Loki charts **7.x+** target **GEL (Grafana Enterprise Logs)** only.
- Do **not** use `grafana/loki` `7.1.0` (or any 7.x series from the historical Grafana repository) for this OSS stack.
- Official migration link: https://grafana.com/docs/loki/latest/setup/upgrade/upgrade-to-community/
- Target: repository `https://grafana-community.github.io/helm-charts`, chart **`18.13.7`**, Loki application **`3.7.8`**.

### Breaking / Loki values

Required corrections in `charts/common-services/values.yaml`:

| Topic | Before (problematic) | After (2.0.3) |
|---|---|---|
| Repository | `grafana/loki` | `grafana-community/loki` |
| `deploymentMode` | `SimpleScalable` | **explicit** `SimpleScalable` (community default = `Monolithic`) |
| `loki.storage.type` | `filesystem` (inconsistent with S3 schema) | `s3` |
| Schema | `object_store: s3`, TSDB **v13**, period `2024-04-01` | **unchanged** (no schema rewrite) |
| Compactor | `delete_request_store: filesystem` | `delete_request_store: s3` |
| Monitoring chart 18 | `monitoring.rules.alerting` | `monitoring.alerts` (+ `monitoring.rules` without the obsolete key) |
| ServiceAccount | generated / not pinned | `serviceAccount.name: loki` (IRSA / pod identity stability) |
| Backend PVC | community default (`whenDeleted: Delete` + auto-delete) | `enableStatefulSetAutoDeletePVC: true` + `whenDeleted/whenScaled: Retain` |

S3 `bucketNames` / region remain **documented placeholders**; secrets and IRSA stay out of Git (environment overlays).

Overlays updated for the new repository / Nebula removal: `charts/common-services/override-values.yaml`, `values-qaibtest.yaml`.

### Backup Manager

- Image aligned: `radiantone/eoc-backup-manager:1.18.2`.
- Removed the legacy documentation UI configuration and associated environment variables (Huma documentation at `/docs`, `/openapi.json`, `/openapi.yaml`).
- Added `backupManager.env` (passthrough) for runtime overrides (e.g. `HTTP_READ_HEADER_TIMEOUT`).
- Ports, probes, and `LISTEN_PORT` aligned on `backupManager.service.containerPort`.

### Velero

- Chart `12.2.0` / app `1.18.2`.
- AWS plugin aligned: `velero/velero-plugin-for-aws:v1.14.4` (compatible with Velero 1.18.2).
- `upgradeCRDs: false` kept — CRDs are applied by **`crds-installer`** at the pinned final version.
- Expected runtime smoke test after sync: backup + restore.

### CloudNativePG / Flink

- CNPG chart `0.29.1` / operator `1.30.1`; CRDs via `crds-installer`; local values unchanged except for incompatibility (none required in this cut).
- Flink Operator `1.15.0` + versioned Apache URL; CRDs via `crds-installer`; webhook remains `create: false`.

### Alloy

- Chart bump `1.13.0` / app `v1.20.0` **only**.
- **DaemonSet** topology kept (`controller.type: daemonset`).
- No HA clustering / StatefulSet in this cut.

### Nebula — complete removal

Ops assumption: **no application still uses Nebula**. If CRs remain in the cluster, they are **deleted anyway** (not fail-closed).

Removed from the chart:

- `nebula-operator` dependency in `Chart.yaml`;
- `nebula-operator` values block;
- overlays (`override-values.yaml`, `values-qaibtest.yaml`);
- workaround template `templates/nebula/controller-manager-patch-rbac.yml`;
- Nebula dashboards (`dashboards/ido/graph-database.json`, `dashboards-logs/ido/nebula-*.json`);
- backup-manager RBAC specific to Nebula;
- Nebula **install** entry in `crds-installer` (no chart left to install).

**`crds-installer`** extension (no separate Job/hook):

1. config entry `action: delete` / `cleanup: true` for the `\.nebula-graph\.io` pattern;
2. list matching CRDs;
3. for each CRD, purge **all** CR instances (cluster-wide / namespaced);
4. remove blocking finalizers if needed;
5. delete the CRDs;
6. no-op if already absent;
7. does not fail because CRs existed — they are purged (`|| true` on cleanup).

Job RBAC widened with verbs on `apps.nebula-graph.io` and `autoscaling.nebula-graph.io`.

### Validation

**Git render (required before merge):**

```bash
helm dependency update charts/common-services
helm lint charts/common-services
helm template test charts/common-services --kube-version 1.34.0 >/dev/null
helm template test charts/common-services --kube-version 1.35.0 >/dev/null
```

**Runtime checklist, non-prod then prod:**

- [ ] Manifest diff limited to the five upgraded components + Nebula removal
- [ ] Velero: backup/restore smoke test after sync
- [ ] Loki: push + query historical S3 logs + new writes; no prolonged mixed-version window
- [ ] CNPG / Flink: operator Ready, existing CRs functionally unchanged
- [ ] Alloy: pods Ready, logs to Loki gateway, Prometheus scrapes
- [ ] Nebula: operator absent, CRs absent, CRDs absent, sync Healthy

### Official links

- Velero upgrade 1.17 : https://velero.io/docs/v1.17/upgrade-to-1.17/
- Velero upgrade 1.18 : https://velero.io/docs/v1.18/upgrade-to-1.18/
- Velero plugin AWS (compat) : https://github.com/vmware-tanzu/velero-plugin-for-aws
- Loki → Grafana Community : https://grafana.com/docs/loki/latest/setup/upgrade/upgrade-to-community/
- Loki community charts : https://grafana-community.github.io/helm-charts
- CloudNativePG charts : https://cloudnative-pg.github.io/charts
- Flink Kubernetes Operator 1.15.0 : https://downloads.apache.org/flink/flink-kubernetes-operator-1.15.0
- Alloy chart : https://github.com/grafana/alloy/tree/main/operations/helm/charts/alloy

### Out of scope (intentional)

- Velero 1.17 / Loki 6.55 intermediate steps and associated scripts/RCs
- Alloy topology redesign (HA clustering)
- Moving Loki off `SimpleScalable` (to be planned before Loki 4.0, not in this cut)
- `velero-ui` bump unless blocked by the new Velero (not observed as blocking here)

---

This file is the **Ops source of truth** for the common-services 2.0.3 upgrade.
