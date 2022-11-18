# radiantone-services

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0](https://img.shields.io/badge/AppVersion-1.0-informational?style=flat-square)

A Helm chart for RadiantOne Common Services on Kubernetes

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| pgodey | <pgodey@radiantlogic.com> | <https://www.radiantlogic.com> |

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://argoproj.github.io/argo-helm | argo-cd | 5.6.0 |
| https://grafana.github.io/helm-charts | grafana | 6.40.0 |
| https://haproxytech.github.io/helm-charts | haproxy | 1.17.3 |
| https://helm.elastic.co | elasticsearch | 7.17.3 |
| https://helm.elastic.co | kibana | 7.17.3 |
| https://prometheus-community.github.io/helm-charts | prometheus | 15.13.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| argo-cd.applicationSet.enabled | bool | `false` |  |
| argo-cd.configs.params."server.rootpath" | string | `"/argocd"` |  |
| argo-cd.controller.nodeSelector | object | `{}` |  |
| argo-cd.crds.keep | bool | `false` |  |
| argo-cd.dex.enabled | bool | `false` |  |
| argo-cd.enabled | bool | `true` |  |
| argo-cd.fullnameOverride | string | `"argocd"` |  |
| argo-cd.notifications.enabled | bool | `false` |  |
| argo-cd.redis.nodeSelector | object | `{}` |  |
| argo-cd.repoServer.nodeSelector | object | `{}` |  |
| argo-cd.server.nodeSelector | object | `{}` |  |
| argo-cd.server.service.type | string | `"NodePort"` |  |
| elasticsearch.enabled | bool | `true` |  |
| elasticsearch.nodeSelector | object | `{}` |  |
| elasticsearch.replicas | int | `1` |  |
| grafana."grafana.ini".server.root_url | string | `"%(protocol)s://%(domain)s/grafana"` |  |
| grafana."grafana.ini".server.serve_from_sub_path | bool | `true` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".apiVersion | int | `1` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].allowUiUpdates | bool | `true` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].disableDeletion | bool | `false` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].editable | bool | `true` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].folder | string | `""` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].name | string | `"fid"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].options.path | string | `"/var/lib/grafana/dashboards/fid"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].orgId | int | `1` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].type | string | `"file"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[0].updateIntervalSeconds | int | `10` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[1].allowUiUpdates | bool | `true` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[1].disableDeletion | bool | `false` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[1].editable | bool | `true` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[1].folder | string | `""` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[1].name | string | `"zookeeper"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[1].options.path | string | `"/var/lib/grafana/dashboards/zookeeper"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[1].orgId | int | `1` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[1].type | string | `"file"` |  |
| grafana.dashboardProviders."dashboardproviders.yaml".providers[1].updateIntervalSeconds | int | `10` |  |
| grafana.dashboardsConfigMaps.fid | string | `"fid-dashboard"` |  |
| grafana.dashboardsConfigMaps.zookeeper | string | `"zookeeper-dashboard"` |  |
| grafana.datasources."datasources.yaml".apiVersion | int | `1` |  |
| grafana.datasources."datasources.yaml".datasources[0].access | string | `"proxy"` |  |
| grafana.datasources."datasources.yaml".datasources[0].isDefault | bool | `true` |  |
| grafana.datasources."datasources.yaml".datasources[0].name | string | `"Prometheus"` |  |
| grafana.datasources."datasources.yaml".datasources[0].type | string | `"prometheus"` |  |
| grafana.datasources."datasources.yaml".datasources[0].url | string | `"http://prometheus-server"` |  |
| grafana.enabled | bool | `true` |  |
| grafana.fullnameOverride | string | `"grafana"` |  |
| grafana.nodeSelector | object | `{}` |  |
| haproxy.config | string | `"defaults\n  timeout connect 10s\n  timeout client 30s\n  timeout server 30s\n  log global\n  mode http\n  option httplog\n  maxconn 3000\nfrontend http-in\n  bind *:80\n\n  stats enable\n  stats refresh 30s\n  stats show-node\n  stats uri /stats\n\n  use_backend grafana_backend if { path /grafana } or { path_beg /grafana/ }\n  use_backend kibana_backend if { path /kibana } or { path_beg /kibana/ }\n  use_backend elasticsearch_backend if { path /elasticsearch } or { path_beg /elasticsearch/ }\n  use_backend prometheus_backend if { path /prometheus } or { path_beg /prometheus/ }\n  use_backend alertmanager_backend if { path /alertmanager } or { path_beg /alertmanager/ }\n  use_backend pushgateway_backend if { path /pushgateway } or { path_beg /pushgateway/ }\nbackend grafana_backend\n  http-request set-path %[path,regsub(^/grafana/?,/)]\n  server grafana grafana:80\nbackend kibana_backend\n  http-request set-path %[path,regsub(^/kibana/?,/)]\n  server kibana kibana:5601\nbackend elasticsearch_backend\n  http-request set-path %[path,regsub(^/elasticsearch/?,/)]\n  server elasticsearch elasticsearch-master:9200\nbackend prometheus_backend\n  http-request set-path %[path,regsub(^/prometheus/?,/)]\n  server prometheus prometheus-server:80\nbackend alertmanager_backend\n  http-request set-path %[path,regsub(^/alertmanager/?,/)]\n  server alertmanager prometheus-alertmanager:80\nbackend pushgateway_backend\n  http-request set-path %[path,regsub(^/pushgateway/?,/)]\n  server pushgateway prometheus-pushgateway:9091\n"` |  |
| haproxy.enabled | bool | `true` |  |
| haproxy.fullnameOverride | string | `"haproxy"` |  |
| haproxy.nodeSelector | object | `{}` |  |
| haproxy.service.type | string | `"NodePort"` |  |
| kibana.enabled | bool | `true` |  |
| kibana.fullnameOverride | string | `"kibana"` |  |
| kibana.kibanaConfig."kibana.yml" | string | `"server.basePath: \"/kibana\"\n"` |  |
| kibana.nodeSelector | object | `{}` |  |
| nodeSelector | object | `{}` |  |
| prometheus.alertmanager.fullnameOverride | string | `"prometheus-alertmanager"` |  |
| prometheus.alertmanager.nodeSelector | object | `{}` |  |
| prometheus.enabled | bool | `true` |  |
| prometheus.kubeStateMetrics.enabled | bool | `false` |  |
| prometheus.nodeExporter.enabled | bool | `false` |  |
| prometheus.pushgateway.fullnameOverride | string | `"prometheus-pushgateway"` |  |
| prometheus.pushgateway.nodeSelector | object | `{}` |  |
| prometheus.server.extraFlags[0] | string | `"web.enable-lifecycle"` |  |
| prometheus.server.extraFlags[1] | string | `"web.route-prefix=/"` |  |
| prometheus.server.extraFlags[2] | string | `"web.external-url=http://prometheus-server/prometheus/"` |  |
| prometheus.server.fullnameOverride | string | `"prometheus-server"` |  |
| prometheus.server.nodeSelector | object | `{}` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.8.1](https://github.com/norwoodj/helm-docs/releases/v1.8.1)
