{{/*
Advanced migration init container.

Fetches the migration artifact (export.zip, and optionally a post-migration script) from a
source other than a plain HTTP URL. Ported from the helm-v8 chart so both chart lines take
the same values shape, but adapted to this chart's conventions: images resolve through
`fid.image`, so `global.imageRegistry` and digest pinning work here too.

PRECEDENCE — deliberately exclusive, matching helm-v8:
  fid.migration.advanced.enabled: true   -> ONLY the advanced block is read.
                                            fid.migration.url / .script are ignored.
  fid.migration.advanced.enabled: false  -> ONLY the legacy fid.migration.url / .script.

Supported source types: http | s3 | gcs | azure | git | db

Credentials are never taken as literal values. Each provider reads them from a Secret you
already have, via `*SecretRef: {name, key}` — which composes with the ESO shim
(externalSecret.*), so a customer can land cloud credentials in a Secret and reference
them here without ever putting them in values.yaml.
*/}}
{{- define "fid.migrationAdvanced" -}}
{{- $adv := (.Values.fid.migration).advanced | default dict -}}
{{- $src := $adv.source | default dict -}}
{{- $type := $src.type | default "" -}}
{{- $img := $adv.image | default dict -}}
- name: migration-advanced
{{- if eq $type "s3" }}
  image: {{ include "fid.image" (dict "image" ($img.s3 | default (dict "repository" "amazon/aws-cli" "tag" "2.15.40")) "context" $) }}
{{- else if eq $type "gcs" }}
  image: {{ include "fid.image" (dict "image" ($img.gcs | default (dict "repository" "gcr.io/google.com/cloudsdktool/google-cloud-cli" "tag" "slim")) "context" $) }}
{{- else if eq $type "azure" }}
  image: {{ include "fid.image" (dict "image" ($img.azure | default (dict "repository" "mcr.microsoft.com/azure-storage/azcopy" "tag" "10.24.0")) "context" $) }}
{{- else if eq $type "git" }}
  image: {{ include "fid.image" (dict "image" ($img.git | default (dict "repository" "alpine/git" "tag" "latest")) "context" $) }}
{{- else if eq $type "db" }}
{{- if eq ($src.db).driver "mysql" }}
  image: {{ include "fid.image" (dict "image" ($img.dbMysql | default (dict "repository" "mysql" "tag" "8.3")) "context" $) }}
{{- else }}
  image: {{ include "fid.image" (dict "image" ($img.dbPostgres | default (dict "repository" "postgres" "tag" "16-alpine")) "context" $) }}
{{- end }}
{{- else }}
  image: {{ include "fid.image" (dict "image" ($img.http | default .Values.helperImages.migration) "context" $) }}
{{- end }}
  imagePullPolicy: {{ $img.pullPolicy | default "IfNotPresent" }}
  resources:
{{- toYaml ($adv.resources | default (dict "limits" (dict "cpu" "100m" "memory" "512Mi") "requests" (dict "cpu" "100m" "memory" "128Mi"))) | nindent 4 }}
{{- with ($adv.securityContext | default (fromYaml (include "fid.helperSecurityContext" $))) }}
  securityContext:
{{- toYaml . | nindent 4 }}
{{- end }}
  env:
{{- /* Credentials sourced from Secrets, never from literal values. */}}
{{- with (($src.s3).auth) }}
{{- if and .accessKeyIdSecretRef .accessKeyIdSecretRef.name }}
  - name: AWS_ACCESS_KEY_ID
    valueFrom:
      secretKeyRef: {name: {{ .accessKeyIdSecretRef.name }}, key: {{ .accessKeyIdSecretRef.key | default "access-key-id" }}}
{{- end }}
{{- if and .secretAccessKeySecretRef .secretAccessKeySecretRef.name }}
  - name: AWS_SECRET_ACCESS_KEY
    valueFrom:
      secretKeyRef: {name: {{ .secretAccessKeySecretRef.name }}, key: {{ .secretAccessKeySecretRef.key | default "secret-access-key" }}}
{{- end }}
{{- end }}
{{- with (($src.azure).auth) }}
{{- if and .sasTokenSecretRef .sasTokenSecretRef.name }}
  - name: AZURE_SAS_TOKEN
    valueFrom:
      secretKeyRef: {name: {{ .sasTokenSecretRef.name }}, key: {{ .sasTokenSecretRef.key | default "sas-token" }}}
{{- end }}
{{- if and .accountKeySecretRef .accountKeySecretRef.name }}
  - name: AZCOPY_ACCOUNT_KEY
    valueFrom:
      secretKeyRef: {name: {{ .accountKeySecretRef.name }}, key: {{ .accountKeySecretRef.key | default "account-key" }}}
{{- end }}
{{- end }}
{{- with (($src.git).auth) }}
{{- if and .usernameSecretRef .usernameSecretRef.name }}
  - name: GIT_USERNAME
    valueFrom:
      secretKeyRef: {name: {{ .usernameSecretRef.name }}, key: {{ .usernameSecretRef.key | default "username" }}}
{{- end }}
{{- if and .tokenSecretRef .tokenSecretRef.name }}
  - name: GIT_TOKEN
    valueFrom:
      secretKeyRef: {name: {{ .tokenSecretRef.name }}, key: {{ .tokenSecretRef.key | default "token" }}}
{{- end }}
{{- end }}
{{- with (($src.db).auth) }}
{{- if and .usernameSecretRef .usernameSecretRef.name }}
  - name: DB_USER
    valueFrom:
      secretKeyRef: {name: {{ .usernameSecretRef.name }}, key: {{ .usernameSecretRef.key | default "username" }}}
{{- end }}
{{- if and .passwordSecretRef .passwordSecretRef.name }}
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef: {name: {{ .passwordSecretRef.name }}, key: {{ .passwordSecretRef.key | default "password" }}}
{{- end }}
{{- end }}
{{- with $adv.extraEnv }}
{{- toYaml . | nindent 2 }}
{{- end }}
  command: ["/bin/sh", "-c"]
  args:
    - |
      set -eu
      echo "Advanced migration fetch: type={{ $type }}"
{{- if eq $type "http" }}
      curl -sSf {{ ($src.http).flags | default "" }} -o /migrations/export.zip {{ ($src.http).url | default "" | quote }}
{{- else if eq $type "s3" }}
      {{- /* Flags are assembled into a variable rather than appended with line
             continuations: when region/endpoint are empty the continuations collapse
             into a dangling "\ \" that the shell parses as a literal-space argument. */}}
      S3_FLAGS=""
      {{- with ($src.s3).region }}
      S3_FLAGS="$S3_FLAGS --region {{ . }}"
      {{- end }}
      {{- with ($src.s3).endpoint }}
      S3_FLAGS="$S3_FLAGS --endpoint-url {{ . }}"
      {{- end }}
      # shellcheck disable=SC2086
      aws s3 cp s3://{{ ($src.s3).bucket }}/{{ ($src.s3).key }} /migrations/export.zip $S3_FLAGS
{{- else if eq $type "gcs" }}
      if command -v gcloud >/dev/null 2>&1; then
        gcloud storage cp gs://{{ ($src.gcs).bucket }}/{{ ($src.gcs).object }} /migrations/export.zip
      else
        gsutil cp gs://{{ ($src.gcs).bucket }}/{{ ($src.gcs).object }} /migrations/export.zip
      fi
{{- else if eq $type "azure" }}
      AZ_URL="https://{{ ($src.azure).accountName }}.blob.core.windows.net/{{ ($src.azure).container }}/{{ ($src.azure).blob }}"
{{- if ((($src.azure).auth).managedIdentity) }}
      azcopy login --identity
      azcopy copy "$AZ_URL" /migrations/export.zip
{{- else if (((($src.azure).auth).sasTokenSecretRef).name) }}
      azcopy copy "${AZ_URL}?${AZURE_SAS_TOKEN}" /migrations/export.zip
{{- else }}
      azcopy copy "$AZ_URL" /migrations/export.zip
{{- end }}
{{- else if eq $type "git" }}
      REPO={{ ($src.git).repo | default "" | quote }}
      REF={{ ($src.git).ref | default "main" | quote }}
      PATH_IN_REPO={{ ($src.git).path | default "export.zip" | quote }}
      if [ -f /root/.ssh/id_rsa ]; then chmod 600 /root/.ssh/id_rsa; fi
      if [ -f /etc/git-known-hosts/known_hosts ]; then
        SSH_OPTS="-o UserKnownHostsFile=/etc/git-known-hosts/known_hosts -o StrictHostKeyChecking=yes"
      else
        SSH_OPTS="-o StrictHostKeyChecking=accept-new"
      fi
      if echo "$REPO" | grep -qE "^git@|^ssh://"; then
        GIT_SSH_COMMAND="ssh ${SSH_OPTS}" git clone --branch "$REF" --depth 1 "$REPO" /tmp/repo
      else
        CLONE="$REPO"
        if [ -n "${GIT_USERNAME:-}" ] && [ -n "${GIT_TOKEN:-}" ]; then
          CLONE=$(echo "$REPO" | sed -E "s|^(https?://)|\1${GIT_USERNAME}:${GIT_TOKEN}@|")
        fi
        git clone --branch "$REF" --depth 1 "$CLONE" /tmp/repo
      fi
      cp "/tmp/repo/${PATH_IN_REPO}" /migrations/export.zip
{{- else if eq $type "db" }}
{{- if eq ($src.db).driver "mysql" }}
      mysql -h {{ ($src.db).host }} -P {{ ($src.db).port | default 3306 }} -u"${DB_USER}" -p"${DB_PASSWORD}" \
        {{ ($src.db).database }} -N -e {{ ($src.db).query | default "" | quote }} > /tmp/db.out
{{- else }}
      export PGPASSWORD="${DB_PASSWORD}"
      psql -h {{ ($src.db).host }} -p {{ ($src.db).port | default 5432 }} -U "${DB_USER}" \
        -d {{ ($src.db).database }} -tAc {{ ($src.db).query | default "" | quote }} > /tmp/db.out
{{- end }}
{{- if eq (($src.db).outputEncoding | default "raw") "base64" }}
      base64 -d /tmp/db.out > /migrations/export.zip
{{- else }}
      cp /tmp/db.out /migrations/export.zip
{{- end }}
{{- else }}
      echo "ERROR: fid.migration.advanced.source.type must be one of http|s3|gcs|azure|git|db (got {{ $type | default "empty" }})" >&2
      exit 1
{{- end }}
{{- with $adv.script }}
{{- if .url }}
      curl -sSf -o /opt/radiantone/scripts/configure_fid.sh {{ .url | quote }}
      chmod +x /opt/radiantone/scripts/configure_fid.sh
{{- end }}
{{- end }}
      echo 'Advanced migration artifacts prepared' && ls -ltr /migrations
  volumeMounts:
  - name: migrations
    mountPath: /migrations
  - name: scripts
    mountPath: /opt/radiantone/scripts
{{- if ((($src.git).auth).sshKeySecretRef).name }}
  - name: git-ssh-key
    mountPath: /root/.ssh
{{- end }}
{{- if ((($src.git).auth).knownHostsConfigMapRef).name }}
  - name: git-known-hosts
    mountPath: /etc/git-known-hosts/known_hosts
    subPath: {{ (($src.git).auth).knownHostsConfigMapRef.key | default "known_hosts" }}
{{- end }}
{{- with $adv.extraVolumeMounts }}
{{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Volumes required by the advanced migration init container (git SSH key / known_hosts).
*/}}
{{- define "fid.migrationAdvancedVolumes" -}}
{{- $src := ((.Values.fid.migration).advanced).source | default dict -}}
{{- if ((($src.git).auth).sshKeySecretRef).name }}
- name: git-ssh-key
  secret:
    secretName: {{ (($src.git).auth).sshKeySecretRef.name }}
    defaultMode: 0400
{{- end }}
{{- if ((($src.git).auth).knownHostsConfigMapRef).name }}
- name: git-known-hosts
  configMap:
    name: {{ (($src.git).auth).knownHostsConfigMapRef.name }}
{{- end }}
{{- end }}
