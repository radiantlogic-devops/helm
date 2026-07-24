# 10 — Upgrades and rollback

## Credential preservation

Each credential resolves as:

1. the explicit value in `values.yaml`
2. **the value already in the live Secret** (looked up in-cluster)
3. a freshly generated random value (first install only)

Step 2 matters. The fallback used to be a bare `randAlphaNum`, which is re-evaluated on
**every render** — so any upgrade run without `fid.rootPassword` / `zk.password` set minted
new credentials and wrote them over the working ones, while running pods kept using the old
values until their next restart.

Verified live: upgrading with both values explicitly emptied preserved `fid-root-password`,
`zk-password` and `fid-license` byte for byte, and FID rejoined its cluster with the same
Cloud ID.

`lookup` is inert during `helm template` / `--dry-run` / `helm lint`, so offline rendering
still produces a random value exactly as before.

## Immutable fields

`spec.selector` and `spec.volumeClaimTemplates` cannot be changed in place. A values change
that would alter either fails the upgrade **partway through**, leaving the release
half-applied. The chart detects this first:

```
PREFLIGHT: this upgrade would change the StatefulSet's immutable selector.
Fix: recreate the StatefulSet, keeping pods and PVCs alive:
  kubectl delete statefulset fid -n my-ns --cascade=orphan
  helm upgrade ...        # re-adopts the running pods
Bypass:   set  preflight.immutableFieldCheck: false
```

`--cascade=orphan` leaves the pods running while the StatefulSet is recreated, so this is
not an outage. Note the ArgoCD UI's REPLACE / orphan dropdown does **not** orphan pods —
you must run the `kubectl delete --cascade=orphan` yourself first.

## What causes a rolling restart

| Change | Rolls pods? |
|---|---|
| `security.profile` | Yes — pod-template fields |
| Adopting the first-party helper images | Yes — image references changed |
| `startupProbe.enabled` | Yes |
| Probe timeouts / thresholds | Yes |
| `metrics.*` (sidecar) | Yes |
| `ingress.advanced.*` | No — separate objects |
| `podDisruptionBudget.*` | No |
| `commonLabels` / `commonAnnotations` | No, on the pod template |

## Rollback

`helm rollback` reverses profile changes exactly — they touch only mutable pod-template
fields. Verified: rolling a live release back to the previously published chart caused
**zero pod churn** (generation unchanged, controller-revision hash unchanged).

Not rollback-safe, and therefore separate toggles rather than part of a profile:

- NetworkPolicy creation/removal
- RBAC scope changes
- anything that alters an immutable field

## Deprecated keys

Renamed values keep working via `coalesce`, and warnings appear in `NOTES.txt` after
install/upgrade rather than failing the render:

| Deprecated | Use instead |
|---|---|
| `metrics.image` | `metrics.imageRepository` |
| `metrics.imageTag` | `metrics.tag` |

## Recommended upgrade sequence

```bash
# 1. See what would change, with cluster lookups active
helm diff upgrade fid radiantone/fid -n my-ns -f values.yaml     # helm-diff plugin
helm upgrade fid radiantone/fid -n my-ns -f values.yaml --dry-run=server

# 2. Upgrade
helm upgrade fid radiantone/fid -n my-ns -f values.yaml --timeout 15m

# 3. Verify
kubectl -n my-ns get sts fid -o jsonpath='{.metadata.generation} {.status.updateRevision}'
helm test fid -n my-ns
```

If generation and revision hash are unchanged, nothing rolled.
