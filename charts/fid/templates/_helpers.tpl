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
Resolve an image reference from an image dict.

Accepts a dict of {registry, repository, tag, digest} and renders "<registry>/<repository>:<tag>"
or "<registry>/<repository>@<digest>" when a digest is set (digest wins over tag).

Registry precedence: image.registry > global.imageRegistry > "" (bare Docker Hub reference).
A tag of "" renders the bare repository, preserving pre-existing untagged references.

Usage: {{ include "fid.image" (dict "image" .Values.initImages.checkZk "context" $) }}
*/}}
{{- define "fid.image" -}}
{{- $img := .image | default dict -}}
{{- $ctx := .context -}}
{{- $registry := $img.registry | default (($ctx.Values.global).imageRegistry) | default "" -}}
{{- $repo := $img.repository -}}
{{- if $registry }}
{{- $repo = printf "%s/%s" (trimSuffix "/" $registry) $repo -}}
{{- end }}
{{- if $img.digest }}
{{- printf "%s@%s" $repo $img.digest -}}
{{- else if $img.tag }}
{{- printf "%s:%s" $repo ($img.tag | toString) -}}
{{- else }}
{{- $repo -}}
{{- end }}
{{- end }}

{{/*
Resolve the main FID image, preserving the historical `image.tag | default .Chart.AppVersion`
fallback while adding registry and digest support.
*/}}
{{- define "fid.mainImage" -}}
{{- $img := .Values.image | default dict -}}
{{- $tag := $img.tag | default .Chart.AppVersion -}}
{{- include "fid.image" (dict "image" (merge (dict "tag" $tag) (omit $img "tag")) "context" .) -}}
{{- end }}

{{/*
Resolve the metrics/exporter sidecar image. `metrics.image` is a bare repository string
(historical shape), so it is adapted into the standard image dict here.
*/}}
{{- define "fid.metricsImage" -}}
{{- $m := .Values.metrics | default dict -}}
{{- include "fid.image" (dict "image" (dict "repository" $m.image "tag" $m.imageTag "registry" $m.registry "digest" $m.digest) "context" .) -}}
{{- end }}

{{/*
Common labels applied to every object the chart renders, on top of "fid.labels".
Purely additive: renders nothing unless .Values.commonLabels is set.
*/}}
{{- define "fid.commonLabels" -}}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Common annotations applied to every object the chart renders.
Purely additive: renders nothing unless .Values.commonAnnotations is set.
*/}}
{{- define "fid.commonAnnotations" -}}
{{- with .Values.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Apply a strategic-merge style patch to a rendered object.

This is the chart's "no ceiling" escape hatch: it lets a user set any field on the rendered
pod spec, including fields the chart does not model. The patch is deep-merged LAST, so it wins
over every typed value and every posture preset.

mergeOverwrite mutates its first argument, so the base is deep-copied first.

Usage:
  {{- $spec := include "fid.podSpec" . | fromYaml }}
  {{- include "fid.applyPatch" (dict "base" $spec "patch" .Values.fid.podSpecPatch) }}

Note: list-valued fields (containers, volumes) are REPLACED wholesale by the patch, not merged
by name — this is Helm's mergeOverwrite semantics, not kubectl's strategic-merge. To adjust a
single container, prefer the typed values; use the patch for fields the chart does not expose.
*/}}
{{- define "fid.applyPatch" -}}
{{- $base := .base | default dict -}}
{{- $patch := .patch | default dict -}}
{{- if $patch -}}
{{- toYaml (mergeOverwrite (deepCopy $base) $patch) -}}
{{- else -}}
{{- toYaml $base -}}
{{- end -}}
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





