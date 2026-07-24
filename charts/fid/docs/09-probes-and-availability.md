# 09 — Probes and availability

## Probes

```yaml
fid:
  livenessProbe:
    initialDelaySeconds: 60
    timeoutSeconds: 5
    periodSeconds: 30
    failureThreshold: 5
    successThreshold: 1
  readinessProbe:
    initialDelaySeconds: 120
    timeoutSeconds: 5
    periodSeconds: 30
    failureThreshold: 5
    successThreshold: 1
```

Every field above is what the chart has always rendered. `periodSeconds`,
`failureThreshold` and `successThreshold` used to be **hardcoded with no way to change
them** — you had to fork the chart.

### When to raise them

FID can block for a long time during a large Lucene index commit or a full GC on the
leader. While blocked it stops answering the liveness exec probe, kubelet kills the
container — **exit 137, which looks exactly like an OOM but is not** — and the cluster
re-elects. A slow operation becomes an outage.

If you run large branches or see unexplained restarts under load:

```yaml
fid:
  livenessProbe:
    timeoutSeconds: 30      # raise this first
    failureThreshold: 10    # then this
```

Distinguish a probe kill from a real OOM:

```bash
kubectl -n my-ns describe pod fid-0 | grep -A3 "Last State"
# Reason: Error   + exit code 137  -> probe kill (or SIGKILL)
# Reason: OOMKilled                -> genuine memory exhaustion
```

### Startup probe — the better fix for slow starts

```yaml
fid:
  startupProbe:
    enabled: true
    periodSeconds: 20
    failureThreshold: 15    # 15 x 20s = 5 minutes of grace
```

A startup probe gives FID a long window to come up **without** permanently weakening the
liveness probe that protects it for the rest of its life. This is the right fix for "FID
gets killed while still loading a large dataset" — much better than inflating
`livenessProbe.initialDelaySeconds`.

Disabled by default because enabling it changes the pod template (a rolling restart).

## PodDisruptionBudget

```yaml
podDisruptionBudget:
  enabled: true
  maxUnavailable: 1
  # minAvailable: 2
```

Rendered by default with `maxUnavailable: 1` — what the chart has always produced.

- **Disable it** on single-replica installs. It gives you nothing and actively hurts: it
  can block `kubectl drain` and stop cluster-autoscaler reclaiming an idle node.
- **Use `minAvailable`** when you care how many stay up rather than how many may go down —
  `minAvailable: 2` on a 3-replica cluster guarantees quorum through a rolling node
  replacement.

Set only one; `minAvailable` wins if both are given.

## Scheduling and spread

The chart models `nodeSelector`, `tolerations` and `affinity` directly. Anything else goes
through `podSpecPatch`:

```yaml
fid:
  podSpecPatch:
    topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels: {app.kubernetes.io/name: fid}
    priorityClassName: system-cluster-critical
    terminationGracePeriodSeconds: 120
```
