{{/*
Pod spec for the follower-only StatefulSet, extracted so fid.followerOnly.podSpecPatch
(falling back to fid.podSpecPatch) can be deep-merged over it — same escape-hatch parity
as the main StatefulSet. nindent values are rebased to column 0. Output unchanged when no
patch is set.
*/}}
{{- define "fid.followerPodSpec" -}}
{{- with (include "fid.imagePullSecrets" . | trim) }}
imagePullSecrets:
{{- . | nindent 0 }}
{{- end }}
securityContext:
{{- include "fid.podSecurityContext" . | nindent 2 }}
initContainers:
{{- if .Values.zk.external }}
- name: check-zk
  image: {{ include "fid.image" (dict "image" .Values.helperImages.checkZk "context" $) }}
  resources:
{{- toYaml (.Values.helperImages.checkZk.resources | default .Values.helperResources) | nindent 4 }}
  imagePullPolicy: {{ .Values.helperImages.checkZk.pullPolicy | default "IfNotPresent" }}
{{- with (.Values.helperImages.checkZk.securityContext | default (fromYaml (include "fid.helperSecurityContext" $))) }}
  securityContext:
{{- toYaml . | nindent 4 }}
{{- end }}
  command: ['sh', '-c', 'until nc -w 2 -z $0 $1; do echo Waiting for zookeeper -- $0:$1;sleep 2; done; echo Connection to zookeeper ok -- $0:$1', '{{ (split ":" .Values.zk.connectionString)._0 }}', '{{ (split ":" .Values.zk.connectionString)._1 }}']
{{- end }}
- name: check-fid
  image: {{ include "fid.image" (dict "image" .Values.helperImages.checkFid "context" $) }}
  imagePullPolicy: {{ .Values.helperImages.checkFid.pullPolicy | default "IfNotPresent" }}
  resources:
{{- toYaml (.Values.helperImages.checkFid.resources | default .Values.helperResources) | nindent 4 }}
{{- with (.Values.helperImages.checkFid.securityContext | default (fromYaml (include "fid.helperSecurityContext" $))) }}
  securityContext:
{{- toYaml . | nindent 4 }}
{{- end }}
  command: ['sh', '-c', 'until nc -w 2 -z $0 $1; do echo Waiting for FID -- $0:$1;sleep 2; done; echo Connection to FID ok -- $0:$1', '{{ include "fid.fullname" . }}-app', '2636']
{{- if hasKey .Values.sysctl "enabled" }}
{{- if .Values.sysctl.enabled }}
- name: sysctl
  image: {{ include "fid.image" (dict "image" .Values.helperImages.sysctl "context" $) }}
  imagePullPolicy: {{ .Values.helperImages.sysctl.pullPolicy | default "IfNotPresent" }}
  resources:
{{- toYaml (.Values.helperImages.sysctl.resources | default .Values.helperResources) | nindent 4 }}
  command: ["/bin/sh", "-c", "sysctl -w vm.max_map_count=262144 && set -e && ulimit -n 65536"]
  securityContext:
{{- toYaml (.Values.helperImages.sysctl.securityContext | default (dict "privileged" true)) | nindent 4 }}
{{- end }}
{{- end }}
{{- with .Values.extraInitContainers }}
{{- tpl (toYaml .) $ | nindent 0 }}
{{- end }}
containers:
- name: {{ .Chart.Name }}
  image: "{{ include "fid.mainImage" . }}"
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  securityContext:
{{- include "fid.containerSecurityContext" . | nindent 4 }}
  lifecycle:
    postStart:
      exec:
        command: ["/bin/sh", "-c", "echo Hello from the myfid postStart handler > /opt/radiantone/vds/lifecycle.txt"]
    preStop:
      exec:
{{- if .Values.fid.followerOnly.detach }}
        command: ["/bin/sh", "-c", "/opt/radiantone/vds/bin/advanced/cluster.sh detach;rm /opt/radiantone/vds/vds_server/conf/cloud.properties"]
{{- else }}
        command: ["/opt/radiantone/vds/bin/stopVDSServer.sh"]
{{- end }}
  ports:
  - containerPort: 2181
    name: zk-client
  - containerPort: 7070
    name: cp-http
  - containerPort: 7171
    name: cp-https
  - containerPort: 9100
    name: admin-http
  - containerPort: 9101
    name: admin-https
  - containerPort: 2389
    name: ldap
  - containerPort: 2636
    name: ldaps
  - containerPort: 8089
    name: http
  - containerPort: 8090
    name: https
{{- include "fid.probes" . | nindent 2 }}
  envFrom:
  - configMapRef:
      name: {{ template "fid.fullname" . }}
{{- if or .Values.envFromSecret (or .Values.envRenderSecret .Values.envFromSecrets) .Values.envFromConfigMaps }}
{{- if .Values.envFromSecret }}
  - secretRef:
      name: {{ tpl .Values.envFromSecret . }}
{{- end }}
{{- if .Values.envRenderSecret }}
  - secretRef:
      name: {{ include "fid.fullname" . }}-env
{{- end }}
{{- range .Values.envFromSecrets }}
  - secretRef:
      name: {{ tpl .name $ }}
      optional: {{ .optional | default false }}
{{- end }}
{{- range .Values.envFromConfigMaps }}
  - configMapRef:
      name: {{ tpl .name $ }}
      optional: {{ .optional | default false }}
{{- end }}
{{- end }}
  env:
{{- if .Values.fid.mountSecrets }}
{{- else }}
  env:
{{- if .Values.fid.rootUser }}
  - name: FID_ROOT_USER
    valueFrom:
      secretKeyRef:
        name: {{ include "fid.secretName" . }}
        key: fid-root-username
{{- end }}
{{- /* fid-root-password is always present in the Secret */}}
  - name: FID_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "fid.secretName" . }}
        key: fid-root-password
{{- if .Values.zk.username }}
  - name: ZK_USER
    valueFrom:
      secretKeyRef:
        name: {{ include "fid.secretName" . }}
        key: zk-username
{{- end }}
{{- /* zk-password is always present in the Secret */}}
  - name: ZK_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "fid.secretName" . }}
        key: zk-password
{{- if include "fid.licenseKeyPresent" . }}
  - name: LICENSE
    valueFrom:
      secretKeyRef:
        name: {{ include "fid.secretName" . }}
        key: fid-license
{{- end }}
{{- end }}
{{- range $key, $value := .Values.env }}
  - name: "{{ tpl $key $ }}"
    value: "{{ tpl (print $value) $ }}"
{{- end }}
{{- /* envValueFrom: name is templated, value is a raw EnvVarSource (configMapKeyRef,
 secretKeyRef, fieldRef, resourceFieldRef). Declared in values.yaml for a long
 time but never rendered - setting it did nothing. */}}
{{- range $key, $value := .Values.envValueFrom }}
  - name: "{{ tpl $key $ }}"
    valueFrom:
{{- tpl (toYaml $value) $ | nindent 6 }}
{{- end }}
  resources:
{{- toYaml .Values.resources | nindent 6 }}
  volumeMounts:
  - name: r1-pvc
    mountPath: /opt/radiantone/vds
{{- if .Values.fid.mountSecrets }}
  - name: fid-creds
    mountPath: /var/secrets
{{- end }}
{{- if .Values.extraVolumeMounts }}
{{- include "common.tplvalues.render" ( dict "value" .Values.extraVolumeMounts "context" $ ) | nindent 2 }}
{{- end }}
  command: ["/bin/sh", "-c"]
  args:
    - |
      export CLUSTER=join;
      export NODE_TYPE=follower;
      ./run.sh fg
{{- if .Values.metrics.enabled }}
- name: {{ .Chart.Name }}-exporter
  image: {{ include "fid.metricsImage" . }}
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 100m
      memory: 128Mi
  ports:
  - containerPort: 9095
    name: exporter
  volumeMounts:
  - name: r1-pvc
    mountPath: /opt/radiantone/vds
{{- if eq .Values.metrics.fluentd.enabled true }}
  - name: fluentd-config-volume
    mountPath: /fluentd/etc
{{- end }}
  securityContext: {{ .Values.metrics.securityContext | default dict | toYaml | nindent 10 }}
  command: ["/bin/sh", "-c", "until nc -w 2 -z localhost 2636; do echo Waiting for fid on port 2636;sleep 10; done;echo \"FID is up!\" && /opt/fidexporter/entry.sh"]
  env:
{{- if .Values.metrics.pushMode }}
  - name: PUSH_MODE
    value: {{ .Values.metrics.pushMode | quote }}
  - name: PUSHGATEWAY_URI
    value: {{ .Values.metrics.pushGateway | quote }}
  - name: PUSH_METRIC_CRON
    value: {{ .Values.metrics.pushMetricCron | quote }}
{{- end }}
  - name: LDAP_URI
    value: "ldaps://localhost:2636"
  - name: JOB_NAME
    valueFrom:
      configMapKeyRef:
        name: {{ template "fid.fullname" . }}
        key: ZK_CLUSTER
{{- if hasKey .Values.metrics "binddn" }}  
    value: {{ .Values.metrics.binddn | quote }}
{{- else }}
    value: "uid=operator,ou=globalusers,cn=config"
{{- end }}
  - name: BIND_PASSWORD
{{- if hasKey .Values.metrics "bindpassword" }}
    value: {{ .Values.metrics.bindpassword | quote }}
{{- else }}
    valueFrom:
      secretKeyRef:
        name: {{ include "fid.secretName" . }}
        key: fid-root-password
{{- end }}
{{- if hasKey .Values.metrics.fluentd "enabled" }}
{{- if .Values.metrics.fluentd.enabled }}
  - name: FLUENTD_ENABLE
    value: {{ .Values.metrics.fluentd.enabled | quote }}
  - name: FLUENTD_CONF
    value: {{ .Values.metrics.fluentd.configFile | quote }}
  # - name: ELASTICSEARCH_HOST
  #   value: {{ .Values.metrics.fluentd.elasticSearchHost | quote }}
  # - name: ELASTICSEARCH_TYPE
  #   value: {{ .Values.metrics.fluentd.elasticSearchType | default "elasticsearch" | quote }}
{{- end }}
{{- end }}

{{- end }}
{{- with .Values.nodeSelector }}
nodeSelector:
{{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
{{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
{{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.topologySpreadConstraints }}
topologySpreadConstraints:
{{- toYaml . | nindent 2 }}
{{- end }}
{{- if .Values.sidecars }}
{{- include "common.tplvalues.render" ( dict "value" .Values.sidecars "context" $ ) | nindent 0 }}
{{- end }}
volumes:
{{- if .Values.fid.mountSecrets }}
- name: fid-creds
  secret:
    defaultMode: 288
    secretName: {{ include "fid.secretName" . }}
{{- end }}
{{- if eq .Values.metrics.fluentd.enabled true }}
- name: fluentd-config-volume
  configMap:
    name: fluentd-config
{{- end }}
{{- if .Values.extraVolumes }}
{{- include "common.tplvalues.render" ( dict "value" .Values.extraVolumes "context" $ ) | nindent 0 }}
{{- end }}
{{- with .Values.extraContainerVolumes }}
{{- tpl (toYaml .) | nindent 2 }}
{{- end }}
{{- if not .Values.persistence.enabled }}
- name: r1-pvc
  emptyDir: {}
{{- end }}
{{- end }}
