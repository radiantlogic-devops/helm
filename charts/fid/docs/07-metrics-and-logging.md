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

**`radiantone/fid-exporter` only exports metrics in PUSH mode.** Its entrypoint starts the
exporter binary solely when `PUSH_MODE=true`. With `pushMode: false`, nothing listens on
`:9095` and Prometheus has nothing to scrape. The `containerPort: 9095` the chart declares
is vestigial for this image.

So with `fid-exporter` you need a Pushgateway:

```yaml
metrics:
  enabled: true
  pushMode: true
  pushGateway: "http://pushgateway:9091"
  pushMetricCron: "* * * * *"
```

Verified end-to-end on a live cluster: **70 FID metric series** (`ldap_connection`,
`ldap_connection_count`, `ldap_connection_max`, `ldap_connection_idle_timeout`, …) landed
in a Pushgateway within one cron interval.

> Prometheus' own guidance is that a Pushgateway is the wrong shape for long-lived services
> — it breaks up/down detection and staleness handling. An exporter serving a scrape
> endpoint is the better end state; see `rl-exporter` below.

## Exporter flavour

```yaml
metrics:
  flavor: fid-exporter      # or rl-exporter
```

`rl-exporter` is the first-party successor. It folds `fid-exporter` + `zk-exporter` +
`metrics-service` into one image, reads metrics from the Admin REST API instead of LDAP
`cn=Monitor`, and fixes the OOM with per-worker on-disk buffers.

**It is not the default** because its image is not published to a public registry yet
(`ghcr.io/radiantlogic-devops/rl-exporter` returns 403; there is no Docker Hub repo), so
defaulting to it would break every install that cannot authenticate. Flip it with:

```yaml
metrics:
  flavor: rl-exporter
  imageRepository: ghcr.io/radiantlogic-devops/rl-exporter
  tag: "<version>"
  resources:
    limits: {memory: 512Mi}    # 128Mi is not enough for rl-exporter
```

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

Verified: Fluentd tails all nine FID log files and shipped `vds_server.log`,
`vds_events.log` and `web.log` to Elasticsearch — 3,361 documents across three indices
within a few minutes of startup.

Per-log control lives under `metrics.fluentd.logs.<name>` (`enabled`, `path`, `index`, and
Splunk-specific `splunk_index` / `splunk_source` / `splunk_sourcetype`).

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
