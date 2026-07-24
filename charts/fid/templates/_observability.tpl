{{/*
Observability sidecar (the new path).

Rendered by _podspec.tpl only when observability.enabled is true, in which case it fully
supersedes the legacy metrics: sidecar. Defaults to the rl-exporter image and its
pull-native, env-driven interface, and mounts the generated fluent.conf from
observability/fluentd-configmap.yaml — the same contract helm-v8 uses.

Kept in its own file and gated behind observability.enabled so that with the flag off the
render is byte-identical to the pre-observability chart.
*/}}

{{/* Is the observability exporter the rl-exporter flavour? */}}
{{- define "fid.obs.isRlExporter" -}}
{{- eq (((.Values.observability).exporter).flavor | default "rl-exporter") "rl-exporter" -}}
{{- end }}

{{/* Resolve the observability exporter image (flavour-driven default). */}}
{{- define "fid.obs.exporterImage" -}}
{{- $e := (.Values.observability).exporter | default dict -}}
{{- $flavorRepo := ternary "radiantone/rl-exporter" "radiantone/fid-exporter" (eq ($e.flavor | default "rl-exporter") "rl-exporter") -}}
{{- $repo := $e.imageRepository | default $flavorRepo -}}
{{- include "fid.image" (dict "image" (dict "repository" $repo "tag" $e.tag "registry" $e.registry "digest" $e.digest) "context" .) -}}
{{- end }}

{{/* Effective securityContext for the observability sidecar (same root reconciliation as
     the legacy path: uid 0 needs runAsNonRoot:false under a hardened profile). */}}
{{- define "fid.obs.securityContext" -}}
{{- $sc := (((.Values.observability).exporter).securityContext | default (fromYaml (include "fid.helperSecurityContext" .))) | default dict -}}
{{- if and (kindIs "invalid" $sc.runAsNonRoot) (eq (toString $sc.runAsUser) "0") -}}
{{- $sc = set (deepCopy $sc) "runAsNonRoot" false -}}
{{- end -}}
{{- if $sc }}{{ toYaml $sc }}{{ end -}}
{{- end }}

{{/* The observability sidecar container. */}}
{{- define "fid.observabilitySidecar" -}}
{{- $e := (.Values.observability).exporter | default dict -}}
{{- $log := ((.Values.observability).logging).fluentd | default dict -}}
{{- $rl := (include "fid.obs.isRlExporter" .) | eq "true" -}}
- name: {{ .Chart.Name }}-exporter
  image: {{ include "fid.obs.exporterImage" . }}
  imagePullPolicy: {{ $e.pullPolicy | default .Values.image.pullPolicy }}
  resources:
{{- toYaml ($e.resources | default (dict "limits" (dict "cpu" "1000m" "memory" "512Mi") "requests" (dict "cpu" "100m" "memory" "128Mi"))) | nindent 4 }}
{{- with (include "fid.obs.securityContext" . | trim) }}
  securityContext:
{{- . | nindent 4 }}
{{- end }}
{{- if $rl }}
  command: ["/bin/sh", "-c", "until nc -w 2 -z localhost 2636; do echo Waiting for fid on port 2636;sleep 10; done; echo \"FID is up!\" && exec /fluentd/bin/entry.sh"]
{{- else }}
  command: ["/bin/sh", "-c", "until nc -w 2 -z localhost 2636; do echo Waiting for fid on port 2636;sleep 10; done;echo \"FID is up!\" && /opt/fidexporter/entry.sh"]
{{- end }}
  ports:
  - containerPort: {{ $e.metricsPort | default 9095 }}
    name: exporter
  env:
  - name: METRICS_ENABLED
    value: {{ .Values.observability.enabled | quote }}
  - name: LOGGING_ENABLED
    value: {{ $log.enabled | default false | quote }}
  - name: METRICS_PORT
    value: {{ $e.metricsPort | default 9095 | quote }}
  - name: LDAP_URI
    value: "ldaps://localhost:2636"
  {{- with $e.adminApiUrl }}
  - name: ADMIN_API_URL
    value: {{ . | quote }}
  {{- end }}
  {{- with $e.zkConn }}
  - name: ZK_CONN
    value: {{ . | quote }}
  {{- end }}
  - name: JOB_NAME
    valueFrom:
      configMapKeyRef:
        name: {{ template "fid.fullname" . }}
        key: ZK_CLUSTER
  {{- if $log.enabled }}
  - name: FLUENTD_ENABLE
    value: "true"
  - name: FLUENTD_CONF
    value: {{ $log.configFile | default "/fluentd/etc/fluent.conf" | quote }}
  {{- end }}
  {{- with $e.extraEnv }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
  volumeMounts:
  - name: r1-pvc
    mountPath: /opt/radiantone/vds
  {{- if $log.enabled }}
  - name: observability-fluentd-config
    mountPath: /fluentd/etc
  {{- end }}
  {{- with $e.extraVolumeMounts }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}
