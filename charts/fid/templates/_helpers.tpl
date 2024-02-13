{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "fid.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "fid.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "fid.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "fid.labels" -}}
helm.sh/chart: {{ include "fid.chart" . }}
{{ include "fid.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "fid.selectorLabels" -}}
app: {{ include "fid.name" . }}
app.kubernetes.io/name: {{ include "fid.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service Selector labels
*/}}
{{- define "fid.serviceSelectorLabels" -}}
app: {{ include "fid.name" . }}
app.kubernetes.io/name: {{ include "fid.name" . }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "fid.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "fid.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create image pull credentials
*/}}
{{- define "imagePullSecret" }}
{{- with .Values.imageCredentials }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password .email (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}



{{/*
This helper template generates the fluent.conf dynamically based on the inputs from values.yaml file.
The supported aggregators are ELASTICSEARCH, OPENSEARCH, SPLUNK
*/}}
{{- define "aggregator.match.store" -}}
  {{- if $.Values.metrics }}
    {{- if $.Values.metrics.fluentd }}
      {{- if $.Values.metrics.fluentd.aggregators }}
        @type copy
        @log_level debug
        {{- $logName := .log }}
        {{- range $.Values.metrics.fluentd.aggregators }}
          {{- if index $.Values.metrics.fluentd.enabledLogs $logName }}
          <store>
          {{- if eq .type "elasticsearch" }}
            @type elasticsearch
            host {{ .host }}
            port {{ .port }}
            logstash_format true
            logstash_prefix {{ $logName }}.log
          {{- end }}
          {{- if eq .type "opensearch" }}
            @type opensearch
            host {{ .host }}
            port {{ .port }}
            logstash_format true
            logstash_prefix {{ $logName }}.log
            disable_rewrite_tag_filter 1
          {{- end }}
          {{- if eq .type "splunk_hec" }}
            @type splunk_hec
            hec_host {{ .hec_hostname }}
            hec_port {{ .hec_port }}
            hec_token {{ .hec_token}}
            insecure_ssl true
            index {{ .splunk_index }}
          {{- end }}
          </store>
          {{- end }}
        {{- end }}
      {{- else }}
        "Error: $.Values.metrics.fluentd.aggregators is not defined"
      {{- end }}
    {{- else }}
      "Error: $.Values.metrics.fluentd is not defined"
    {{- end }}
  {{- else }}
    "Error: $.Values.metrics is not defined"
  {{- end }}
{{- end }}





