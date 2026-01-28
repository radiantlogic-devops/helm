# Grafana Alloy Dashboards

## Status
Official Grafana Alloy dashboards are not yet published on Grafana.com with a stable dashboard ID.

## Manual Installation

To use Alloy dashboards:

1. Clone the Alloy repository:
   ```bash
   git clone https://github.com/grafana/alloy.git
   cd alloy/operations/alloy-mixin/dashboards
   ```

2. Copy dashboards to this folder:
   ```bash
   cp alloy-operational.json /path/to/common-services/dashboards/alloy/
   cp alloy-logs.json /path/to/common-services/dashboards/alloy/
   cp alloy-cluster-overview.json /path/to/common-services/dashboards/alloy/
   ```

3. Redeploy the chart:
   ```bash
   helm upgrade --install common-services .
   ```

## Alternative
Use Grafana's built-in data source metrics or create custom dashboards from Alloy's self-metrics.
