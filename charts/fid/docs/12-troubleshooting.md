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

## No logs in Elasticsearch, but the pod looks healthy

Check in this order.

**1. Is Fluentd even running?**

```bash
kubectl -n my-ns exec fid-0 -c fid-exporter -- ps aux | grep -c '[f]luentd'
```

`0` means it never started. The usual cause is a **Pushgateway outage**: the entrypoint
runs `verify_pushgateway || exit 1` before the logging block, so with `pushMode: true` and
an unreachable gateway it blocks there forever. The container stays `Running` and `Ready`
and logs nothing about it.

```bash
# the tell: initialization never completed
kubectl -n my-ns logs fid-0 -c fid-exporter | grep -c "Initialization complete"   # 0 = stuck
```

Fix: make `metrics.pushGateway` reachable, or set `pushMode: false` (which disables metrics
but lets Fluentd start unconditionally).

**2. Do the log files have content?**

```bash
kubectl -n my-ns exec fid-0 -c fid -- ls -la /opt/radiantone/vds/vds_server/logs/
```

On a quiet, freshly installed FID only `vds_server.log`, `vds_events.log` and
`jetty/web.log` have content — the five access logs are 0 bytes and two files do not exist.
Fluentd cannot ship an empty file, so seeing three indices is normal. Access logging is a
**FID-side setting**, not a chart one.

**3. Did anything new get written?**

Fluentd resumes from its last read position, so it only ships **newly appended** lines. A
pod restart does not re-ship existing content, and recreating Elasticsearch does not bring
old documents back.

**4. Is the aggregator reachable?**

```bash
kubectl -n my-ns exec fid-0 -c fid-exporter -- \
  curl -s --max-time 5 http://<es-host>:9200/_cluster/health
```

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
