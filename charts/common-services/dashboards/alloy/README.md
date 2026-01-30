# Grafana Alloy Dashboards

## Included Dashboard

- `alloy-cluster-dashboard.json` - Cluster overview dashboard (Grafana Dashboard ID: 19624)

This dashboard is automatically provisioned when:
- `grafana.enabled: true`
- `alloy.enabled: true`

## Metrics

Alloy exposes metrics on port 12345 at `/metrics`. The service is configured with Prometheus annotations for automatic scraping:

```yaml
alloy:
  service:
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "12345"
      prometheus.io/path: "/metrics"
```

## Key Metrics

| Metric | Description |
|--------|-------------|
| `alloy_build_info` | Build information |
| `alloy_component_*` | Component-level metrics |
| `alloy_resources_*` | Resource usage metrics |
