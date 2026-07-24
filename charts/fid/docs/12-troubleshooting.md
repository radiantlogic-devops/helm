# 12 — Troubleshooting

## FID never becomes ready

**Check `mountSecrets` against your image version.** On a 7.x image with
`fid.mountSecrets: true`, FID starts, cannot read its credentials and never goes Ready.
The preflight check catches this; if you bypassed it, this is why.

```yaml
fid:
  mountSecrets: false   # required for any image < 8.0.0
```

## Pods stuck Pending

1. **No matching nodes.** On Duplo, `nodeSelector.tenantname` must match the namespace, and
   the node group may be scaled to zero — the autoscaler needs ~45s to add one.
2. **StorageClass does not exist.** See [06 — Storage](06-storage.md#the-default-trap). The
   default `"default"` is a class *name* and most clusters have no such class.

```bash
kubectl -n my-ns describe pod fid-0 | tail -20
kubectl get sc
```

## `check-zk` init container loops forever

FID and ZooKeeper are on different tenants' nodes and per-tenant security groups block the
traffic. Co-locate them:

```yaml
nodeSelector:      {tenantname: "duploservices-mytenant"}
zookeeper:
  nodeSelector:    {tenantname: "duploservices-mytenant"}
```

## `CreateContainerConfigError` on the exporter

```
Error: container's runAsUser breaks non-root policy
```

The exporter needs uid 0; a hardened profile sets pod-level `runAsNonRoot: true`. Current
chart versions reconcile this automatically. If you see it, you have explicitly set
`metrics.securityContext.runAsNonRoot: true` alongside `runAsUser: 0` — drop one.

Note a pod stuck in this state keeps its **old spec**; fixing values and upgrading is not
enough, you must delete the pod so it is recreated:

```bash
kubectl -n my-ns delete pod fid-0
```

## Pod restarts that are not FID

Check **which container** restarted:

```bash
kubectl -n my-ns get pod fid-0 \
  -o jsonpath='{range .status.containerStatuses[*]}{.name}={.restartCount} {end}'
```

If it is `fid-exporter`, it is the Fluentd sidecar OOMing, usually because the log
aggregator cannot keep up. Raise its limit — see
[07 — Metrics and logging](07-metrics-and-logging.md#the-oom).

If it is `fid` with **exit 137 and Reason: Error** (not `OOMKilled`), it is a liveness probe
kill during a long index commit or GC pause — see
[09 — Probes](09-probes-and-availability.md#when-to-raise-them).

## `helm upgrade` fails partway

Usually an immutable field. See
[10 — Upgrades](10-upgrades-and-rollback.md#immutable-fields) for the `--cascade=orphan`
recovery.

If a release is stuck in `pending-upgrade`, another operation is holding it:

```bash
helm history fid -n my-ns
helm rollback fid <last-good-revision> -n my-ns
```

## Credentials changed unexpectedly after an upgrade

Fixed in current chart versions (values are preserved from the live Secret). On older
versions, any upgrade without `fid.rootPassword` / `zk.password` set regenerated them.
Always set them explicitly, or use [ESO](04-secrets-and-eso.md).

## Ingress returns 502

- **nginx → an HTTPS port**: set `networking.nginx.backendProtocolHTTPS: true`.
- **Traefik → self-signed FID cert**: set `networking.traefik.serversTransport` to a
  transport with `insecureSkipVerify`.
- **Wrong route order**: a `/` route matching before `/rest-service`. Lower the specific
  route's `order`.

## LDAPS through the ingress fails certificate validation

TLS is passed through by design — FID presents its own certificate, not the ingress's. If
your client expects the edge certificate, that is the misconfiguration. Terminating at the
edge instead would break SASL EXTERNAL client authentication.

## NetworkPolicy has no effect

Your CNI probably does not enforce it:

```bash
kubectl -n kube-system get ds aws-node -o jsonpath='{..args}' | tr ',' '\n' | grep network-policy
```

On EKS with the AWS VPC CNI you need `--enable-network-policy=true`. With it false the
object is accepted and silently ignored.

## `helm test` — zookeeper suite fails, fid suites pass

The ZooKeeper subchart's test pod sets **no `nodeSelector`**, so on a multi-tenant cluster
it can be scheduled onto another tenant's node where security groups block it. Not a FID
chart fault. The three `fid-test-*` suites are the meaningful ones.

## Useful one-liners

```bash
# version actually running
kubectl -n my-ns exec fid-0 -c fid -- /opt/radiantone/vds/bin/show_version.sh

# cluster membership and leader
kubectl -n my-ns logs fid-0 -c fid | grep -A5 "VDS Status"

# ZooKeeper ensemble roles
for i in 0 1 2; do kubectl -n my-ns exec zookeeper-$i -- sh -c 'echo srvr | nc localhost 2181 | grep Mode'; done

# did the last upgrade roll the pods?
kubectl -n my-ns get sts fid -o jsonpath='gen={.metadata.generation} rev={.status.updateRevision}'
```
