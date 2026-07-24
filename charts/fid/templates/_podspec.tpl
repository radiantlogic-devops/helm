{{/*
Pod spec for the main FID StatefulSet.

Extracted into a named template so that `fid.podSpecPatch` can be deep-merged over the
rendered result (see statefulset.yaml). This is the ONLY definition of the pod spec.

Note: the non-persistent `r1-pvc` emptyDir volume used to live in the else-branch of the
`persistence.enabled` conditional that also wrapped volumeClaimTemplates. That single
conditional straddled two YAML levels (pod spec and StatefulSet spec), so it has been split
into two inverse conditions. Rendered output is unchanged.
*/}}
{{- define "fid.podSpec" -}}
{{- with (include "fid.imagePullSecrets" . | trim) }}
imagePullSecrets:
{{- . | nindent 6 }}
{{- end }}
{{- with (include "fid.automountServiceAccountToken" .) }}
automountServiceAccountToken: {{ . }}
{{- end }}
securityContext:
{{- include "fid.podSecurityContext" . | nindent 8 }}
initContainers:
{{- if .Values.zk.external }}
- name: check-zk
  image: {{ include "fid.image" (dict "image" .Values.helperImages.checkZk "context" $) }}
  imagePullPolicy: {{ .Values.helperImages.checkZk.pullPolicy | default "IfNotPresent" }}
  resources:
{{- toYaml (.Values.helperImages.checkZk.resources | default .Values.helperResources) | nindent 10 }}
{{- with (.Values.helperImages.checkZk.securityContext | default (fromYaml (include "fid.helperSecurityContext" $))) }}
  securityContext:
{{- toYaml . | nindent 10 }}
{{- end }}
  command: ['sh', '-c', 'until nc -w 2 -z $0 $1; do echo Waiting for zookeeper -- $0:$1;sleep 2; done; echo Connection to zookeeper ok -- $0:$1', '{{ (split ":" .Values.zk.connectionString)._0 }}', '{{ (split ":" .Values.zk.connectionString)._1 }}']
- name: check-zk-readonly
  image: {{ include "fid.image" (dict "image" .Values.helperImages.checkZkReadonly "context" $) }}
  imagePullPolicy: {{ .Values.helperImages.checkZkReadonly.pullPolicy | default "IfNotPresent" }}
  resources:
{{- toYaml (.Values.helperImages.checkZkReadonly.resources | default .Values.helperResources) | nindent 10 }}
{{- with (.Values.helperImages.checkZkReadonly.securityContext | default (fromYaml (include "fid.helperSecurityContext" $))) }}
  securityContext:
{{- toYaml . | nindent 10 }}
{{- end }}
  command: ['sh', '-c', 'until $(curl --silent http://$0:8080/commands/is_read_only | grep false >> /dev/null); do echo Waiting for zookeeper to be writeable;sleep 5; done; echo zookeeper is writable', '{{ (split ":" .Values.zk.connectionString)._0 }}']
{{- end }}
{{- if hasKey .Values.sysctl "enabled" }}
{{- if .Values.sysctl.enabled }}
- name: sysctl
  image: {{ include "fid.image" (dict "image" .Values.helperImages.sysctl "context" $) }}
  imagePullPolicy: {{ .Values.helperImages.sysctl.pullPolicy | default "IfNotPresent" }}
  resources:
{{- toYaml (.Values.helperImages.sysctl.resources | default .Values.helperResources) | nindent 10 }}
  command: ["/bin/sh", "-c", "sysctl -w vm.max_map_count=262144 && set -e && ulimit -n 65536"]
  securityContext:
{{- toYaml (.Values.helperImages.sysctl.securityContext | default (dict "privileged" true)) | nindent 10 }}
{{- end }}
{{- end }}
{{- /* Migration artifact fetch.
       Advanced takes precedence and is EXCLUSIVE: when enabled the legacy
       fid.migration.url / .script fields are ignored entirely, matching helm-v8. */}}
{{- if (((.Values.fid.migration).advanced).enabled) }}
{{- include "fid.migrationAdvanced" . | nindent 0 }}
{{- else if (.Values.fid.migration).url }}
- name: migration
  image: {{ include "fid.image" (dict "image" .Values.helperImages.migration "context" $) }}
  imagePullPolicy: {{ .Values.helperImages.migration.pullPolicy | default "IfNotPresent" }}
  resources:
{{- toYaml (.Values.helperImages.migration.resources | default .Values.helperResources) | nindent 10 }}
{{- with (.Values.helperImages.migration.securityContext | default (fromYaml (include "fid.helperSecurityContext" $))) }}
  securityContext:
{{- toYaml . | nindent 10 }}
{{- end }}
  command: ["/bin/sh", "-c"]
  args:
    - |
      set -ex
      # Download the curl package
      # apk add -q --no-cache curl
      # Download the migrations file
      curl -sSo /migrations/export.zip {{ .Values.fid.migration.url }}

      echo 'Migration file copied to /migrations/export.zip' && ls -ltr /migrations
{{- if hasKey .Values.fid.migration "script" }}
{{- if .Values.fid.migration.script }}
      # Download the script
      curl -sSo /opt/radiantone/scripts/configure_fid.sh {{ .Values.fid.migration.script }}
      # make it executable
      chmod +x /opt/radiantone/scripts/configure_fid.sh
      echo 'Post migration script copied to /opt/radiantone/scripts/configure_fid.sh' && ls -ltr /opt/radiantone/scripts
{{- end }}
{{- end }}
  volumeMounts:
  - name: migrations
    mountPath: /migrations
{{- if hasKey .Values.fid.migration "script" }}
{{- if .Values.fid.migration.script }}
  - name: scripts
    mountPath: /opt/radiantone/scripts
{{- end }}
{{- end }}
{{- end }}

{{- /* extraInitContainers used to be nested inside the migration.url conditional,
       so it silently did nothing unless a migration URL happened to be set. */}}
{{- with .Values.extraInitContainers }}
{{- tpl (toYaml .) $ | nindent 0 }}
{{- end }}
containers:
- name: {{ .Chart.Name }}
  image: "{{ include "fid.mainImage" . }}"
  imagePullPolicy: {{ .Values.image.pullPolicy }}
{{- with (fromYaml (include "fid.containerSecurityContext" $)) }}
  securityContext:
{{- toYaml . | nindent 10 }}
{{- end }}
  lifecycle:
    postStart:
      exec:
        command: ["/bin/sh", "-c", "echo Hello from the myfid postStart handler > /opt/radiantone/vds/lifecycle.txt"]
    preStop:
      exec:
{{- if .Values.fid.detach }}
        command: ["/opt/radiantone/vds/bin/advanced/cluster.sh", "detach"]
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
  readinessProbe:
    tcpSocket:
      port: {{ .Values.fid.readinessProbe.port | default 2636 }}
    initialDelaySeconds: {{ .Values.fid.readinessProbe.initialDelaySeconds }}
    timeoutSeconds: {{ .Values.fid.readinessProbe.timeoutSeconds }}
    periodSeconds: {{ .Values.fid.readinessProbe.periodSeconds | default 30 }}
    failureThreshold: {{ .Values.fid.readinessProbe.failureThreshold | default 5 }}
    successThreshold: {{ .Values.fid.readinessProbe.successThreshold | default 1 }}
  livenessProbe:
    exec:
      command: {{ .Values.fid.livenessProbe.command | default (list "/opt/radiantone/check" "run" "-type" "liveness") | toJson }}
    initialDelaySeconds: {{ .Values.fid.livenessProbe.initialDelaySeconds }}
    timeoutSeconds: {{ .Values.fid.livenessProbe.timeoutSeconds }}
    periodSeconds: {{ .Values.fid.livenessProbe.periodSeconds | default 30 }}
    failureThreshold: {{ .Values.fid.livenessProbe.failureThreshold | default 5 }}
    successThreshold: {{ .Values.fid.livenessProbe.successThreshold | default 1 }}
{{- with .Values.fid.startupProbe }}
{{- if .enabled }}
  startupProbe:
    exec:
      command: {{ .command | default (list "/opt/radiantone/check" "run" "-type" "liveness") | toJson }}
    initialDelaySeconds: {{ .initialDelaySeconds | default 0 }}
    timeoutSeconds: {{ .timeoutSeconds | default 5 }}
    periodSeconds: {{ .periodSeconds | default 20 }}
    failureThreshold: {{ .failureThreshold | default 15 }}
    successThreshold: 1
{{- end }}
{{- end }}
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
{{- if .Values.fid.rootUser }}
  - name: FID_ROOT_USER
    valueFrom:
      secretKeyRef:
        name: {{ include "fid.secretName" . }}
        key: fid-root-username
{{- end }}
{{- /* fid-root-password is always present in the Secret (explicit, preserved, or generated) */}}
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
{{- /* zk-password is always present in the Secret (explicit, preserved, or generated) */}}
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
{{- toYaml .Values.resources | nindent 12 }}
  volumeMounts:
  - name: r1-pvc
    mountPath: /opt/radiantone/vds
  - name: migrations
    mountPath: /migrations
  - name: scripts
    mountPath: /opt/radiantone/scripts
{{- if .Values.fid.mountSecrets }}
  - name: fid-creds
    mountPath: /var/secrets
{{- end }}
{{- if .Values.extraVolumeMounts }}
{{- include "common.tplvalues.render" ( dict "value" .Values.extraVolumeMounts "context" $ ) | nindent 8 }}
{{- end }}

{{- if .Values.fid.readonly }}
  command: ["/bin/sh", "-c", "export CLUSTER=join;./run.sh fg"]
{{- else }}
  command: ["/bin/sh", "-c"]
  args:
    - |
      #set -ex
      if [ $HOSTNAME != {{ template "fid.fullname" . }}-0 ]; then
        export CLUSTER=join;
      fi;

      # Run the startup script
      ./run.sh

{{- if .Values.postInstall.enabled }}
        ## if CURRENT_BUILDID="" it is a new install
        if [ -e $RLI_HOME/.CURRENT_BUILDID ]; then
          CURRENT_BUILDID=$(cat $RLI_HOME/.CURRENT_BUILDID)
        fi;
        if [ "$CURRENT_BUILDID" = "" ]; then
          echo ">> Running post install script"
{{- if .Values.postInstall.leaderOnly }}
          if [ $HOSTNAME = {{ template "fid.fullname" . }}-0 ]; then
{{ .Values.postInstall.script | nindent 14 }}
          fi;
{{- else }}
{{ .Values.postInstall.script | nindent 14 }}
{{- end }}
        fi;
{{- end }}

{{- if .Values.postStart.enabled }}
        echo ">> Running post startup script"
{{- if .Values.postStart.leaderOnly }}
        if [ $HOSTNAME = {{ template "fid.fullname" . }}-0 ]; then
{{ .Values.postStart.script | nindent 14 }}
        fi;
{{- else }}
{{ .Values.postStart.script | nindent 14 }}
{{- end }}
{{- end }}
      tail -f /dev/null
{{- end }}
{{- if .Values.metrics.enabled }}
- name: {{ .Chart.Name }}-exporter
  image: {{ include "fid.metricsImage" . }}
  imagePullPolicy: {{ (.Values.metrics).pullPolicy | default .Values.image.pullPolicy }}
  {{- /* The sidecar's memory limit was hardcoded at 1Gi. This container runs Fluentd (the
         name "fid-exporter" is historical and misleading), and it OOMs at 1Gi on busy nodes
         when the log aggregator is too slow to drain its buffer - the single most common
         cause of "FID pod restarted" that is not FID at all. Now values-driven so it can be
         raised without forking, with the historical values as the default. */}}
  resources:
{{- toYaml ((.Values.metrics).resources | default (dict "limits" (dict "cpu" "1000m" "memory" "1Gi") "requests" (dict "cpu" "100m" "memory" "128Mi"))) | nindent 4 }}
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
{{- with (include "fid.exporterSecurityContext" $ | trim) }}
  securityContext:
{{- . | nindent 4 }}
{{- end }}
{{- if (include "fid.isRlExporter" .) | eq "true" }}
  {{- /* rl-exporter is a single Go binary that reads env and serves :9095 for scraping.
         No shell orchestration, and crucially no pushgateway gate on log shipping. */}}
  command: ["/bin/sh", "-c", "until nc -w 2 -z localhost 2636; do echo Waiting for fid on port 2636;sleep 10; done; echo \"FID is up!\" && exec /fluentd/bin/entry.sh"]
{{- else }}
  command: ["/bin/sh", "-c", "until nc -w 2 -z localhost 2636; do echo Waiting for fid on port 2636;sleep 10; done;echo \"FID is up!\" && /opt/fidexporter/entry.sh"]
{{- end }}
  env:
{{- if (include "fid.isRlExporter" .) | eq "true" }}
  {{- /* rl-exporter env surface (verified against the image): pull-native, independent
         metrics/logging toggles, reads metrics from the Admin REST API. */}}
  - name: METRICS_ENABLED
    value: {{ .Values.metrics.enabled | quote }}
  - name: LOGGING_ENABLED
    value: {{ (.Values.metrics.fluentd).enabled | default false | quote }}
  - name: METRICS_PORT
    value: {{ (.Values.metrics).metricsPort | default 9095 | quote }}
  - name: LDAP_URI
    value: "ldaps://localhost:2636"
  {{- with (.Values.metrics).adminApiUrl }}
  - name: ADMIN_API_URL
    value: {{ . | quote }}
  {{- end }}
  {{- with (.Values.metrics).zkConn }}
  - name: ZK_CONN
    value: {{ . | quote }}
  {{- end }}
{{- else }}
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
  - name: BIND_DN
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
{{- end }}{{/* end flavor if/else for the LDAP/push block */}}
{{- if hasKey .Values.metrics.fluentd "enabled" }}
{{- if .Values.metrics.fluentd.enabled }}
  - name: FLUENTD_ENABLE
    value: {{ .Values.metrics.fluentd.enabled | quote }}
  {{- if (include "fid.isRlExporter" .) | eq "true" }}
  {{- $agg := first (.Values.metrics.fluentd.aggregators | default list) }}
  {{- with $agg }}
  - name: ELASTICSEARCH_HOST
    value: {{ .host | quote }}
  - name: ELASTICSEARCH_PORT
    value: {{ .port | default 9200 | quote }}
  {{- end }}
  {{- else }}
  - name: FLUENTD_CONF
    value: {{ .Values.metrics.fluentd.configFile | quote }}
  {{- end }}
{{- end }}
{{- end }}

{{- end }}
{{- with .Values.nodeSelector }}
nodeSelector:
{{- toYaml . | nindent 8 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
{{- toYaml . | nindent 8 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
{{- toYaml . | nindent 8 }}
{{- end }}
{{- with .Values.extraContainers }}
{{- tpl (toYaml .) $ | nindent 0 }}
{{- end }}
{{- if .Values.sidecars }}
{{- include "common.tplvalues.render" ( dict "value" .Values.sidecars "context" $ ) | nindent 6 }}
{{- end }}
volumes:
- name: scripts
  emptyDir: {}
- name: migrations
  emptyDir: {}
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
{{- include "common.tplvalues.render" ( dict "value" .Values.extraVolumes "context" $ ) | nindent 6 }}
{{- end }}
{{- include "fid.migrationAdvancedVolumes" . | nindent 0 }}
{{- with .Values.extraContainerVolumes }}
{{- tpl (toYaml .) | nindent 8 }}
{{- end }}
{{- if not .Values.persistence.enabled }}
- name: r1-pvc
  emptyDir: {}
{{- end }}
{{- end }}
