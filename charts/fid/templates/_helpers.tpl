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
{{- /* coalesce: new key wins, deprecated key still honoured (see fid.deprecationWarnings).
       When neither is set, the repository default follows metrics.flavor so switching the
       flavour actually switches the image rather than only its behaviour. */ -}}
{{- $flavorRepo := ternary "radiantone/rl-exporter" "radiantone/fid-exporter" (eq ($m.flavor | default "fid-exporter") "rl-exporter") -}}
{{- $repo := coalesce $m.imageRepository $m.image $flavorRepo -}}
{{- $tag := coalesce $m.tag $m.imageTag -}}
{{- include "fid.image" (dict "image" (dict "repository" $repo "tag" $tag "registry" $m.registry "digest" $m.digest) "context" .) -}}
{{- end }}

{{/*
Is the metrics sidecar the rl-exporter flavour?
*/}}
{{- define "fid.isRlExporter" -}}
{{- eq ((.Values.metrics).flavor | default "fid-exporter") "rl-exporter" -}}
{{- end }}

{{/*
Deprecated-key compatibility shims.

Renamed values keep working for at least one minor release. Each shim reads the new key
first and falls back to the old one, so existing values files do not break on upgrade.

`fid.deprecationWarnings` collects a human-readable list, surfaced in NOTES.txt after
install/upgrade rather than failing the render — a warning that blocks a deploy is not a
warning, it is a breaking change.

Currently shimmed:
  metrics.image / metrics.imageTag  ->  metrics.imageRepository / metrics.tag  (aligns the
      metrics sidecar with the standard {repository,tag,digest,registry} image shape used
      everywhere else in this chart)
*/}}
{{- define "fid.deprecationWarnings" -}}
{{- $w := list -}}
{{- if (.Values.metrics).image -}}
{{- $w = append $w "metrics.image is deprecated; use metrics.imageRepository (same value)." -}}
{{- end -}}
{{- if (.Values.metrics).imageTag -}}
{{- $w = append $w "metrics.imageTag is deprecated; use metrics.tag (same value)." -}}
{{- end -}}
{{- if $w }}{{ toYaml $w }}{{ end -}}
{{- end }}

{{/*
Merged image pull secrets: .Values.imagePullSecrets plus .Values.global.imagePullSecrets,
deduplicated by name. Renders nothing when both are empty, preserving historical output.
*/}}
{{- define "fid.imagePullSecrets" -}}
{{- $all := concat (.Values.imagePullSecrets | default list) ((.Values.global).imagePullSecrets | default list) -}}
{{- $seen := dict -}}
{{- $out := list -}}
{{- range $all -}}
{{- $n := .name | default (toString .) -}}
{{- if not (hasKey $seen $n) -}}
{{- $seen = set $seen $n true -}}
{{- $out = append $out (dict "name" $n) -}}
{{- end -}}
{{- end -}}
{{- if $out }}{{ toYaml $out }}{{ end -}}
{{- end }}

{{/*
Name of the Secret holding the FID/ZK credentials.

Defaults to the chart-managed "rootcreds-<fullname>". Set fid.existingSecret to point every
consumer at a Secret you manage instead — External Secrets Operator, Sealed Secrets, the
Vault CSI driver, or one created by hand. When set, the chart does not render a Secret.

The Secret must carry these keys (all optional except where FID needs them):
  fid-root-username, fid-root-password, zk-username, zk-password, fid-license
*/}}
{{- define "fid.secretName" -}}
{{- .Values.fid.existingSecret | default (printf "rootcreds-%s" (include "fid.fullname" .)) -}}
{{- end }}

{{/*
Whether the credentials Secret will carry the `fid-license` key.

The credential env vars must be gated on what the SECRET actually contains, not on what is
set in values.yaml. Those two drifted apart once credential preservation was added: with
fid.license unset but a value preserved from the live Secret, gating on the value alone
dropped the env var while the key was still there.

fid-root-password and zk-password need no equivalent helper — secret.yaml always emits
them (explicit value, else preserved, else generated).

With fid.existingSecret the chart cannot inspect the Secret's contents, so all documented
keys are assumed present; supplying them is the user's side of that contract.
*/}}
{{- define "fid.licenseKeyPresent" -}}
{{- if .Values.fid.existingSecret -}}
true
{{- else if .Values.fid.license -}}
true
{{- else -}}
{{- $live := (lookup "v1" "Secret" .Release.Namespace (include "fid.secretName" .)) | default dict -}}
{{- if index ($live.data | default dict) "fid-license" -}}
true
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Effective automountServiceAccountToken.

Renders nothing on the vanilla/baseline profiles (historical behaviour: the field is
absent, so Kubernetes defaults it to true). The hardened and paranoid profiles default it
to false, since FID itself never calls the Kubernetes API — only the hook Jobs do, and
they use their own ServiceAccount.

An explicit .Values.automountServiceAccountToken always wins, including setting it back to
true under a hardened profile.
*/}}
{{- define "fid.automountServiceAccountToken" -}}
{{- if not (kindIs "invalid" .Values.automountServiceAccountToken) -}}
{{- .Values.automountServiceAccountToken -}}
{{- else if has ((.Values.security).profile | default "vanilla") (list "hardened" "paranoid") -}}
false
{{- end -}}
{{- end }}

{{/*
Resolve the effective storageClass for the FID PVC.

persistence.storageClass accepts:
  "auto"   discover the best class in the cluster (see ranking below)
  "-"      explicitly no class (disables dynamic provisioning)
  ""       omit the field entirely, letting the cluster default apply
  <name>   use that class verbatim

WHY "auto" AND WHY IT IS NOT THE DEFAULT
The historical default was the literal string "default", which is a class NAME. Most
clusters (EKS, GKE, kind) have no class called "default", so PVCs sat Pending forever with
no obvious cause. "auto" fixes that class of mistake by looking at what actually exists.

RANKING, best first — encryption and expandability are what matter for a directory that
grows and holds identity data:
  1. default-annotated class that is BOTH encrypted and expandable
  2. any class that is both encrypted and expandable
  3. default-annotated class that is expandable
  4. any expandable class
  5. the cluster's default-annotated class
  6. nothing -> omit storageClassName and let the cluster decide

"Encrypted" is inferred from the class name or its parameters (encrypted: "true", or a
kms/encryption key parameter), since there is no portable API field for it.

`lookup` returns nothing during `helm template`, `--dry-run` and `helm lint`, so an
offline render of "auto" omits the field rather than guessing — the same result as an
empty value. Always check the resolved class with a real `--dry-run=server` or by
inspecting the created PVC.
*/}}
{{- define "fid.storageClass" -}}
{{- $want := (.Values.persistence).storageClass | default "" -}}
{{- if ne $want "auto" -}}
{{- $want -}}
{{- else -}}
{{- $classes := (lookup "storage.k8s.io/v1" "StorageClass" "" "") -}}
{{- $best := "" -}}
{{- $bestScore := -1 -}}
{{- range (($classes).items | default list) -}}
{{- $isDefault := or (eq (index (.metadata.annotations | default dict) "storageclass.kubernetes.io/is-default-class") "true") (eq (index (.metadata.annotations | default dict) "storageclass.beta.kubernetes.io/is-default-class") "true") -}}
{{- $expandable := eq (toString .allowVolumeExpansion) "true" -}}
{{- $p := .parameters | default dict -}}
{{- $encrypted := or (eq (toString (index $p "encrypted")) "true") (hasKey $p "kmsKeyId") (hasKey $p "encryptionKey") (hasKey $p "diskEncryptionSetID") (contains "encrypt" (lower .metadata.name)) -}}
{{- $score := 0 -}}
{{- if and $encrypted $expandable $isDefault }}{{ $score = 60 }}
{{- else if and $encrypted $expandable }}{{ $score = 50 }}
{{- else if and $expandable $isDefault }}{{ $score = 40 }}
{{- else if $expandable }}{{ $score = 30 }}
{{- else if $isDefault }}{{ $score = 20 }}
{{- else }}{{ $score = 10 }}{{ end -}}
{{- if gt $score $bestScore }}{{ $bestScore = $score }}{{ $best = .metadata.name }}{{ end -}}
{{- end -}}
{{- $best -}}
{{- end -}}
{{- end }}

{{/*
Effective securityContext for the metrics/logging sidecar.

This container legitimately needs uid 0: it tails FID's log files, which FID writes as its
own user with restrictive modes. That collides with a pod-level `runAsNonRoot: true` from
the hardened/paranoid profiles — kubelet rejects the pod with

    Error: container's runAsUser breaks non-root policy

which is an obscure way to learn about a values conflict. A container-level
`runAsNonRoot: false` overrides the pod-level policy, so whenever the resolved runAsUser is
0 we emit it automatically instead of making the operator know this Kubernetes subtlety.

An explicit metrics.securityContext.runAsNonRoot always wins, so you can still force the
strict behaviour and let the pod fail if that is genuinely what you want.
*/}}
{{- define "fid.exporterSecurityContext" -}}
{{- $sc := ((.Values.metrics).securityContext | default (fromYaml (include "fid.helperSecurityContext" .))) | default dict -}}
{{- /* NB: `$sc.runAsUser | default ""` would swallow the value, because Go templates
       treat 0 as empty and `default` fires on it. Compare the raw value. */ -}}
{{- if and (kindIs "invalid" $sc.runAsNonRoot) (eq (toString $sc.runAsUser) "0") -}}
{{- $sc = set (deepCopy $sc) "runAsNonRoot" false -}}
{{- end -}}
{{- if $sc }}{{ toYaml $sc }}{{ end -}}
{{- end }}

{{/*
Tenant name — the namespace with the Duplo "duploservices-" prefix stripped.
Used by the fluentd Loki aggregator labels (ported from helm-v8).
*/}}
{{- define "tenant.name" -}}
{{- trimPrefix "duploservices-" .Release.Namespace -}}
{{- end }}

{{/*
Render a container probe with full configurability.

Params: probe (the .Values.fid.<x>Probe map), defaults (timing defaults dict), handler
(the default handler dict, e.g. {tcpSocket: {port: 2636}} or {exec: {command: [...]}}).

Precedence, low to high:
  1. `defaults` timing (initialDelaySeconds/timeoutSeconds/periodSeconds/failureThreshold/
     successThreshold) and the default `handler`
  2. any timing field set on the probe map
  3. an explicit handler on the probe map (exec / httpGet / tcpSocket / grpc) replaces the
     default handler entirely — so you can switch a TCP probe to httpGet, etc.
  4. probe.overrides — a raw map deep-merged last, for any probe field the above do not
     model (terminationGracePeriodSeconds on the probe, extra httpGet headers, ...)

This makes every probe field reachable without forking the chart.  See docs/09.
*/}}
{{- define "fid.probe" -}}
{{- $p := .probe | default dict -}}
{{- $out := deepCopy (.defaults | default dict) -}}
{{- /* timing overrides from the probe map */ -}}
{{- range $k := (list "initialDelaySeconds" "timeoutSeconds" "periodSeconds" "failureThreshold" "successThreshold") -}}
{{- $v := index $p $k -}}
{{- if not (kindIs "invalid" $v) }}{{ $_ := set $out $k $v }}{{ end -}}
{{- end -}}
{{- /* handler: an explicit one on the probe replaces the default */ -}}
{{- $userHandler := dict -}}
{{- range $hk := (list "exec" "httpGet" "tcpSocket" "grpc") -}}
{{- with index $p $hk }}{{ $_ := set $userHandler $hk . }}{{ end -}}
{{- end -}}
{{- if $userHandler }}
{{- $out = merge $out $userHandler -}}
{{- else }}
{{- $out = merge $out (deepCopy (.handler | default dict)) -}}
{{- end -}}
{{- /* raw escape hatch, merged last */ -}}
{{- with $p.overrides }}{{ $out = mergeOverwrite $out (deepCopy .) }}{{ end -}}
{{- toYaml $out -}}
{{- end }}

{{/*
The FID container's three probes, rendered from fid.readinessProbe / livenessProbe /
startupProbe. Startup is only emitted when enabled. Shared by the main and follower
StatefulSets so probe configuration applies to both.
*/}}
{{- define "fid.probes" -}}
{{- $liveCmd := list "/opt/radiantone/check" "run" "-type" "liveness" -}}
readinessProbe:
{{- include "fid.probe" (dict
    "probe" .Values.fid.readinessProbe
    "defaults" (dict "initialDelaySeconds" 120 "timeoutSeconds" 5 "periodSeconds" 30 "failureThreshold" 5 "successThreshold" 1)
    "handler" (dict "tcpSocket" (dict "port" (.Values.fid.readinessProbe.port | default 2636)))
  ) | nindent 2 }}
livenessProbe:
{{- include "fid.probe" (dict
    "probe" .Values.fid.livenessProbe
    "defaults" (dict "initialDelaySeconds" 60 "timeoutSeconds" 5 "periodSeconds" 30 "failureThreshold" 5 "successThreshold" 1)
    "handler" (dict "exec" (dict "command" (.Values.fid.livenessProbe.command | default $liveCmd)))
  ) | nindent 2 }}
{{- if (.Values.fid.startupProbe).enabled }}
startupProbe:
{{- include "fid.probe" (dict
    "probe" .Values.fid.startupProbe
    "defaults" (dict "initialDelaySeconds" 0 "timeoutSeconds" 5 "periodSeconds" 20 "failureThreshold" 15 "successThreshold" 1)
    "handler" (dict "exec" (dict "command" (.Values.fid.startupProbe.command | default $liveCmd)))
  ) | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Security posture presets.

These supply DEFAULTS ONLY. Anything set explicitly in values.yaml
(podSecurityContext / securityContext / helperSecurityContext) is deep-merged on top and WINS.

  vanilla   - the chart's historical behaviour. No securityContext hardening at all.
              This is a fully supported destination, not a legacy state: if you want root,
              privileged and no restrictions, stay here.
  baseline  - roughly Pod Security Standards "baseline". No privilege escalation,
              RuntimeDefault seccomp. Safe for essentially every workload.
  hardened  - roughly PSS "restricted". Non-root, all capabilities dropped, read-only
              root filesystem on the helper containers.
  paranoid  - hardened, plus a read-only root filesystem on the FID container itself.
              REQUIRES writable volume mounts for every path FID writes to - see the
              security.profile notes in values.yaml. Verify before using in production.
  custom    - no preset at all. You supply every field yourself.

To REMOVE a field a preset sets (rather than override its value), use profile: custom,
or fid.podSpecPatch, which is applied after everything else.
*/}}
{{- define "fid.securityPresets" -}}
vanilla:
  pod: {}
  container: {}
  helper: {}
baseline:
  pod: {}
  container:
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
  helper:
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
hardened:
  pod:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  container:
    allowPrivilegeEscalation: false
    runAsNonRoot: true
    runAsUser: 1000
    capabilities:
      drop:
      - ALL
    seccompProfile:
      type: RuntimeDefault
  helper:
    allowPrivilegeEscalation: false
    runAsNonRoot: true
    runAsUser: 1000
    readOnlyRootFilesystem: true
    capabilities:
      drop:
      - ALL
    seccompProfile:
      type: RuntimeDefault
paranoid:
  pod:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  container:
    allowPrivilegeEscalation: false
    runAsNonRoot: true
    runAsUser: 1000
    readOnlyRootFilesystem: true
    capabilities:
      drop:
      - ALL
    seccompProfile:
      type: RuntimeDefault
  helper:
    allowPrivilegeEscalation: false
    runAsNonRoot: true
    runAsUser: 1000
    readOnlyRootFilesystem: true
    capabilities:
      drop:
      - ALL
    seccompProfile:
      type: RuntimeDefault
custom:
  pod: {}
  container: {}
  helper: {}
{{- end }}

{{/*
Look up one layer ("pod" | "container" | "helper") of the active security preset.
*/}}
{{- define "fid.securityPreset" -}}
{{- $profile := ((.context.Values.security).profile | default "vanilla") -}}
{{- $all := fromYaml (include "fid.securityPresets" .context) -}}
{{- $sel := index $all $profile -}}
{{- if not $sel }}{{ fail (printf "security.profile %q is not one of: vanilla, baseline, hardened, paranoid, custom" $profile) }}{{ end -}}
{{- toYaml (index $sel .layer | default dict) -}}
{{- end }}

{{/*
Effective pod-level securityContext: preset defaults, with values.yaml merged over the top.
*/}}
{{- define "fid.podSecurityContext" -}}
{{- $preset := fromYaml (include "fid.securityPreset" (dict "layer" "pod" "context" .)) -}}
{{- toYaml (mergeOverwrite (deepCopy $preset) (.Values.podSecurityContext | default dict)) -}}
{{- end }}

{{/*
Effective container-level securityContext for the FID container.
*/}}
{{- define "fid.containerSecurityContext" -}}
{{- $preset := fromYaml (include "fid.securityPreset" (dict "layer" "container" "context" .)) -}}
{{- toYaml (mergeOverwrite (deepCopy $preset) (.Values.securityContext | default dict)) -}}
{{- end }}

{{/*
Effective securityContext for the helper / init containers.
*/}}
{{- define "fid.helperSecurityContext" -}}
{{- $preset := fromYaml (include "fid.securityPreset" (dict "layer" "helper" "context" .)) -}}
{{- toYaml (mergeOverwrite (deepCopy $preset) (.Values.helperSecurityContext | default dict)) -}}
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

{{/*
Built-in defaults for helperImages — kept identical to values.yaml.

Their reason for existing is `helm upgrade --reuse-values`: that flag reuses ONLY the prior
release's values and does NOT layer the new chart's values.yaml on top, so a release
installed from an older chart (which had no `helperImages:` block at all) would render the
new templates with `.Values.helperImages` nil and crash on the first `.checkZk` index.

`fid.helperImagesInit` backfills any missing key with `merge` (user values always win), so:
  * default render is byte-identical (the user already has every key → merge is a no-op), and
  * --reuse-values from any prior chart still resolves every helper image.

Consuming templates call `{{- include "fid.helperImagesInit" . -}}` once, up top.
*/}}
{{- define "fid.helperImagesDefaults" -}}
checkZk:         {repository: radiantone/init-tools, tag: latest, pullPolicy: IfNotPresent, resources: {limits: {cpu: 100m, memory: 128Mi}, requests: {cpu: 100m, memory: 128Mi}}}
checkZkReadonly: {repository: radiantone/curl,       tag: latest, pullPolicy: IfNotPresent, resources: {limits: {cpu: 100m, memory: 128Mi}, requests: {cpu: 100m, memory: 128Mi}}}
checkFid:        {repository: radiantone/init-tools, tag: latest, pullPolicy: IfNotPresent, resources: {limits: {cpu: 100m, memory: 128Mi}, requests: {cpu: 100m, memory: 128Mi}}}
sysctl:          {repository: busybox,               tag: latest, pullPolicy: IfNotPresent, resources: {limits: {cpu: 100m, memory: 128Mi}, requests: {cpu: 100m, memory: 128Mi}}}
migration:       {repository: radiantone/curl,       tag: latest, pullPolicy: IfNotPresent, resources: {limits: {cpu: 100m, memory: 512Mi}, requests: {cpu: 100m, memory: 128Mi}}}
hooks:           {repository: radiantone/kubectl,    tag: latest}
testCurl:        {repository: radiantone/curl,       tag: latest}
testBusybox:     {repository: busybox,               tag: ""}
{{- end }}

{{- define "fid.helperImagesInit" -}}
{{- $_ := set .Values "helperImages" (merge (.Values.helperImages | default dict) (fromYaml (include "fid.helperImagesDefaults" .))) -}}
{{- end }}


