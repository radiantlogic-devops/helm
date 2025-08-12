{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "common-services.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "common-services.fullname" -}}
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
{{- define "common-services.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "common-services.labels" -}}
helm.sh/chart: {{ include "common-services.chart" . }}
{{ include "common-services.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "common-services.selectorLabels" -}}
app.kubernetes.io/name: {{ include "common-services.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
slamd Selector labels
*/}}
{{- define "slamd.selectorLabels" -}}
app.kubernetes.io/name: slamd
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
shell Selector labels
*/}}
{{- define "shellinabox.selectorLabels" -}}
app.kubernetes.io/name: shellinabox
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
smtp Selector labels
*/}}
{{- define "smtp.selectorLabels" -}}
app.kubernetes.io/name: smtp
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
zoonavigator Selector labels
*/}}
{{- define "zoonavigator.selectorLabels" -}}
app.kubernetes.io/name: zoonavigator
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "common-services.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "common-services.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the appropriate apiVersion for cronjob APIs.
*/}}
{{- define "cronjob.apiVersion" -}}
{{- if semverCompare "< 1.8-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "batch/v2alpha1" }}
{{- else if semverCompare "1.8-0 - 1.20" .Capabilities.KubeVersion.GitVersion -}}
{{- print "batch/v1beta1" }}
{{- else -}}
{{- print "batch/v1" }}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for podsecuritypolicy.
*/}}
{{- define "podsecuritypolicy.apiVersion" -}}
{{- if semverCompare "<1.10-0" .Capabilities.KubeVersion.GitVersion -}}
{{- print "extensions/v1beta1" -}}
{{- else -}}
{{- print "policy/v1beta1" -}}
{{- end -}}
{{- end -}}


{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "elasticsearch-curator.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Backup Manager Selector labels
*/}}
{{- define "backup-manager.selectorLabels" -}}
app.kubernetes.io/name: backup-manager
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Get dependency information by name
Usage: {{ include "common-services.getDependency" (dict "name" "cloudnative-pg" "context" .) }}
*/}}
{{- define "common-services.getDependency" -}}
{{- $name := .name -}}
{{- $context := .context -}}
{{- $result := dict -}}
{{- range $context.Chart.Dependencies -}}
{{- if eq .Name $name -}}
{{- $_ := set $result "name" .Name -}}
{{- $_ := set $result "version" .Version -}}
{{- $_ := set $result "repository" .Repository -}}
{{- end -}}
{{- end -}}
{{- $result | toJson -}}
{{- end }}
