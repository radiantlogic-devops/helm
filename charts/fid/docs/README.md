# FID Helm chart documentation

Configuration guide for `radiantlogic-devops/helm` → `charts/fid` (the **v7 chart line**,
FID 7.x). For FID 8.x / IDDM see the separate `helm-v8` repository.

## Start here

| Guide | Read it when |
|---|---|
| [01 — Getting started](01-getting-started.md) | First install, or you want a working values file to copy |
| [02 — Images and registries](02-images-and-registries.md) | Airgapped/mirrored installs, digest pinning, which images need pull secrets |
| [03 — Security profiles](03-security-profiles.md) | Hardening, running non-root, Pod Security Standards |
| [04 — Secrets and ESO](04-secrets-and-eso.md) | Vault, AWS Secrets Manager, bring-your-own Secret, credential rotation |
| [05 — Ingress and external access](05-ingress.md) | NGINX / Traefik / Istio, exposing the Control Panel or LDAPS |
| [06 — Storage and persistence](06-storage.md) | PVCs, storage classes, resizing volumes |
| [07 — Metrics and logging](07-metrics-and-logging.md) | Prometheus, Elasticsearch, the exporter sidecar |
| [08 — Migration](08-migration.md) | Seeding a new cluster from an existing export.zip |
| [09 — Probes and availability](09-probes-and-availability.md) | Unexplained restarts, slow startup, PodDisruptionBudgets |
| [10 — Upgrades and rollback](10-upgrades-and-rollback.md) | Before you upgrade. Immutable fields, credential preservation |
| [11 — Escape hatches](11-escape-hatches.md) | The chart does not model the thing you need |
| [12 — Troubleshooting](12-troubleshooting.md) | Something is broken |
| [13 — Values reference](13-values-reference.md) | Full annotated key list |

## The one rule

**This chart does not restrict you.** Every default can be overridden, every generated
object can be replaced with your own, every safety check can be switched off, and
`fid.podSpecPatch` can set fields the chart has never heard of. If you hit a wall, it is a
bug — see [11 — Escape hatches](11-escape-hatches.md).

The corollary: the defaults are chosen to be *safe and unchanged*, not clever. Installing
this chart with no values behaves exactly as it always has.
