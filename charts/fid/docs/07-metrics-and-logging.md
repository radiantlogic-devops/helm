# 07 — Metrics and logging

```yaml
metrics:
  enabled: true
  pushMode: true
  pushGateway: "http://pushgateway:9091"
  fluentd:
    enabled: true
    aggregators:
      - type: elasticsearch
        host: elasticsearch-master
        port: 9200
```

## The sidecar is misnamed

The container is called `fid-exporter`, but when `metrics.fluentd.enabled` is true it runs
**both** a metrics exporter and Fluentd. It is usually Fluentd doing the work — which is
why this is the container that OOMs, not FID.

## Push vs pull — read this before wiring Prometheus

`pushMode` does more than choose a transport. **It decides whether the exporter binary runs
at all** — the image's entrypoint starts it only when `PUSH_MODE=true`.

| `pushMode` | Exporter process | `:9095` | Pushgateway |
|---|---|---|---|
| `false` | not started | nothing listening | — |
| `true` | running | **serves metrics** | pushed every `pushMetricCron` |

So `pushMode: false` does not mean "pull instead of push" — it means **no metrics at all**.

### ⚠️ A Pushgateway outage silently kills log shipping

This is the single most surprising behaviour of this sidecar.

The image's entrypoint runs `verify_pushgateway || exit 1` **before** it starts Fluentd. If
`pushGateway` is unreachable, the entrypoint blocks there and never reaches the logging
block — **Fluentd never starts**, and nothing in the container logs says so. The container
stays `Running` and `Ready` throughout, and the pod looks healthy.

Proven on a live cluster with identical values, changing only the gateway's reachability:

| Pushgateway | `Initialization complete` | Fluentd processes | Files tailed | ES documents |
|---|---|---|---|---|
| deleted | ✗ never logged | **0** | 0 | none |
| restored | ✓ | **5** | 8 | 1,013 |

So if you enable `pushMode`, you must keep a Pushgateway reachable **even if you intend to
scrape `:9095` instead of using it**.

To run logging without that coupling, set `pushMode: false` — Fluentd then starts
unconditionally, and you get no metrics. Metrics and logging are not independently
selectable in this image.

### Scraping :9095 directly

Verified: **65 FID metric series** served on `:9095` when the exporter is running. Combined
with the constraint above:

```yaml
metrics:
  enabled: true
  pushMode: true                                   # starts the exporter AND requires...
  pushGateway: "http://pushgateway:9091"           # ...this to be reachable
```

Then scrape the pod's `:9095` and ignore the gateway's contents if you prefer.

Verified both paths simultaneously: **70 series** reached a Pushgateway within one cron
interval, and **65 series** were readable directly from `:9095`.

> Prometheus' own guidance is that a Pushgateway is the wrong shape for long-lived services
> — it breaks up/down detection and staleness handling. **Prefer scraping `:9095`.**

### Scraping with the Prometheus Operator

The chart does not render a ServiceMonitor. Add one via `extraObjects`:

```yaml
extraObjects:
  - apiVersion: monitoring.coreos.com/v1
    kind: ServiceMonitor
    metadata:
      name: "{{ include \"fid.fullname\" . }}"
    spec:
      selector:
        matchLabels:
          app.kubernetes.io/instance: "{{ .Release.Name }}"
      endpoints:
        - port: exporter      # containerPort 9095
          interval: 30s
```

## Exporter flavour

```yaml
metrics:
  flavor: fid-exporter      # or rl-exporter
```

`rl-exporter` is the first-party successor. It folds `fid-exporter` + `zk-exporter` +
`metrics-service` into one image, reads metrics from the Admin REST API instead of LDAP
`cn=Monitor`, and fixes the OOM with per-worker on-disk buffers.

Setting `flavor: rl-exporter` switches **three** things at once:

- the image default → `radiantone/rl-exporter`
- the container command → `/fluentd/bin/entry.sh` (rl-exporter's, not fid-exporter's)
- the env → `METRICS_ENABLED` / `LOGGING_ENABLED` / `ADMIN_API_URL` / `ELASTICSEARCH_HOST`
  rather than `PUSH_MODE` / `PUSHGATEWAY_URI` / `BIND_DN`

### rl-exporter is pull-native — no Pushgateway, no gate

Unlike fid-exporter, rl-exporter is a single Go binary that serves `:9095` for scraping and
ships logs directly. **It has none of fid-exporter's coupling**: metrics and logging are
independent toggles, and there is no `verify_pushgateway` step that can block log shipping.
Point Prometheus straight at `:9095`.

```yaml
metrics:
  enabled: true
  flavor: rl-exporter
  imageRepository: ""          # empty => radiantone/rl-exporter
  tag: "<version>"
  resources:
    limits: {memory: 512Mi}    # 128Mi is not enough for rl-exporter
  fluentd:
    enabled: true
    aggregators:
      - {type: elasticsearch, host: elasticsearch, port: 9200}
```

### Two caveats, both verified on a live cluster

Tested end-to-end against FID 7.4.23 with Prometheus, Elasticsearch, Kibana and Grafana:

1. **It is not the default**, because `radiantone/rl-exporter` is not published to a public
   registry yet. Defaulting to it would break every install that cannot authenticate. Set
   `imageRepository` to wherever you publish it (the current dev build lives at
   `rahulnutakki/rl-exporter:dev`).

2. **rl-exporter targets FID 8.x.** On 7.4.23 its rich metrics come back empty: the Admin
   REST API paths it scrapes (`/adminapp/data/metrics/{cluster-info,node-monitor,...}`)
   return **HTTP 404**, and its bundled Fluentd template is absent from the `dev` image, so
   **logging is silently disabled**. What DID work on 7.x: it started cleanly, served
   `:9095`, and Prometheus scraped it healthy (target UP, 0 errors) — but only
   `fid_service_status` and `rl_exporter_is_primary` carried data. And `fid_service_status`
   reported the **inverse of reality** (it marked closed ports up and open ports down),
   because its probe logic assumes the 8.x port layout.

   Bottom line: on this chart line (FID 7.x), **fid-exporter is the working exporter**.
   rl-exporter is wired and ready for when this chart is pointed at an 8.x image, and for
   validation once its image is published — but it is not a drop-in on 7.x today.

Both are chart-independent (image behaviour and image packaging); the chart renders
rl-exporter correctly, verified by the sidecar coming up 2/2 and Prometheus scraping it.

## The `metrics.advanced:` block — new logging model (rl-exporter)

`metrics:` (above) is the original path and stays the default. `metrics.advanced:` is a newer,
opt-in block that **supersedes `metrics:` when `metrics.advanced.enabled: true`** and brings
the full helm-v8 logging model to this chart line:

- **Named aggregators** — define an output once, reference it by name from any log
- **Eight output types** — elasticsearch, opensearch, splunk_hec, loki, sumologic, s3,
  azure_event_hubs, opentelemetry — with SSL/TLS options
- **Per-log `retention_days`** and optional Kibana index-pattern / ES ILM creation
- **Fan-out** — one log to several backends at once

```yaml
metrics:
  advanced:
    enabled: true                 # supersedes metrics: entirely
    exporter:
      flavor: rl-exporter         # default here (metrics: defaults to fid-exporter)
      imageRepository: ""         # empty => radiantone/rl-exporter
    logging:
      enabled: true
      fluentd:
        enabled: true
        logs:
          vds_server:
            enabled: true
            path: "/opt/radiantone/vds/vds_server/logs/vds_server.log"
            index: vds_server.log
            retention_days: 30
            aggregators: ["default", "splunk", "loki"]   # fan out to three
        aggregators:
          - {name: default, type: elasticsearch, host: es, port: "9200"}
          - {name: splunk,  type: splunk_hec, hec_host: splunk, hec_port: "8088", hec_token: T}
          - {name: loki,    type: loki, url: "http://loki:3100"}
```

When `metrics.advanced.enabled: false` (the default) none of this renders and the chart
behaves exactly as before via `metrics:`.

### Verified live — and it fixes rl-exporter logging on 7.x

Deployed on qa-self-managed against FID 7.4.23 with rl-exporter (`rahulnutakki/rl-exporter:dev`)
and Elasticsearch. Result: **~14,800 documents across 5 indices**
(`vds_server.log-fid-cluster-…`, `web.log-fid-cluster-…`, `vds_events.log-…`, etc.).

This is the important part: the *earlier* rl-exporter test (using the `metrics:` path's
fid-exporter-shaped wiring) had **logging disabled** — rl-exporter logged "template not
found" and ran no Fluentd. The `metrics.advanced:` path mounts the **generated fluent.conf**
into the sidecar (the same contract helm-v8 uses), and with it rl-exporter's Fluentd starts,
tails all the FID logs and ships them. The index names carry the cluster name
(`…-fid-cluster-…`), confirming the traffic routes through the ported named-aggregator
config rather than any built-in default.

Metrics are unchanged from the earlier finding: rl-exporter serves `:9095` and Prometheus
scrapes it, but its rich FID metrics still 404 on the 7.x Admin REST API. So on this chart
line: **`metrics.advanced:` logging works today with rl-exporter; its metrics wait for an 8.x
image.** The block renders and validates now for both.

## Logging to Elasticsearch / OpenSearch / Splunk

```yaml
metrics:
  fluentd:
    enabled: true
    aggregators:
      - type: elasticsearch
        host: elasticsearch-master
        port: 9200
      # - type: opensearch
      #   host: opensearch-cluster-master
      #   port: 9200
      # - type: splunk_hec
      #   hec_hostname: splunk.example.com
      #   hec_port: 8088
      #   hec_token: "..."
      #   splunk_index: fid
```

Per-log control lives under `metrics.fluentd.logs.<name>` (`enabled`, `path`, `index`, and
Splunk-specific `splunk_index` / `splunk_source` / `splunk_sourcetype`).

### Which logs actually appear in Elasticsearch

The chart configures **10** log files, but you will normally see far fewer indices. That is
correct behaviour, not a failure — Fluentd cannot ship a file that is empty or absent.

Measured on a freshly installed FID 7.4.23:

| Log | On disk | Index created |
|---|---|---|
| `vds_server.log` | 175 KB | ✅ |
| `vds_events.log` | 105 KB | ✅ |
| `jetty/web.log` | 708 KB | ✅ |
| `vds_server_access.csv` | **0 bytes** | ✗ |
| `jetty/web_access.log` | **0 bytes** | ✗ |
| `adap_access.log` | **0 bytes** | ✗ |
| `admin_rest_api_access.log` | **0 bytes** | ✗ |
| `periodiccache.log` | **0 bytes** | ✗ |
| `sync_engine.log` | **absent** | ✗ |
| `alerts.log` | **absent** | ✗ |

Fluentd tailed 8 of the 10 (it skips the two that do not exist, and picks them up later if
they appear).

**The access logs stay at 0 bytes even under load.** Generating 30 HTTP requests and 30+
LDAP binds against a running FID did not add a single byte to `vds_server_access.csv`,
`web_access.log` or `admin_rest_api_access.log`. Access logging is a **FID-side setting**,
not a chart one — enable it in FID's own configuration (Control Panel → logging, or
`vds_server.conf`) if you need those indices.

So "only three indices appeared" is the expected result on a quiet, freshly installed
instance. Check the file sizes before assuming the pipeline is broken:

```bash
kubectl -n my-ns exec fid-0 -c fid -- \
  ls -la /opt/radiantone/vds/vds_server/logs/
```

### Fluentd resumes from its last position

Fluentd records how far it has read. After a restart it continues from there, so a pod
restart does **not** re-ship existing log content — only newly appended lines. If you
recreate Elasticsearch, previously shipped documents are gone and will not be re-sent.

## The OOM

The sidecar's memory limit **used to be hardcoded at 1Gi**. It buffers logs, so a slow or
unreachable Elasticsearch makes it grow until the kernel kills it — and the restart count
lands on the pod, which reads as "FID restarted" when FID was fine.

It is now values-driven:

```yaml
metrics:
  resources:
    limits: {cpu: 1000m, memory: 2Gi}     # raise this before blaming FID
    requests: {cpu: 100m, memory: 128Mi}
```

Check which container actually restarted:

```bash
kubectl -n my-ns get pod fid-0 -o jsonpath='{range .status.containerStatuses[*]}{.name}={.restartCount} {end}'
```

## Running the exporter under a hardened profile

The sidecar needs uid 0 to read FID's log files. The chart reconciles that with pod-level
`runAsNonRoot: true` automatically — see
[03 — Security profiles](03-security-profiles.md#the-exporter-needs-root--and-the-chart-handles-it).
