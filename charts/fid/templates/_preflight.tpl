{{/*
Preflight checks.

These run at render time and stop an install or upgrade that would fail confusingly later.
Every one of them can be switched off individually via `preflight.<name>: false`, because a
check that cannot be bypassed is a restriction, and this chart does not restrict.

Included from statefulset.yaml so it runs on every render.
*/}}
{{- define "fid.preflight" -}}
{{- $pf := .Values.preflight | default dict }}

{{- /* ------------------------------------------------------------------------------
     1. mountSecrets vs image version.

     fid.mountSecrets: true mounts the credentials as files, which only FID 8.0.0+ can
     read. Point the chart at a 7.x image with the default and FID starts, fails to find
     its credentials and the pod never becomes ready — with nothing in the events to
     explain why.

     Only fires when the tag actually parses as semver, so "latest", "nightly" or a
     custom tag never trips it.
     ------------------------------------------------------------------------------ */}}
{{- if ne $pf.mountSecretsVersionCheck false }}
{{- $tag := (.Values.image.tag | default .Chart.AppVersion | toString) }}
{{- if and .Values.fid.mountSecrets (regexMatch "^[0-9]+\\.[0-9]+\\.[0-9]+" $tag) }}
{{- if semverCompare "< 8.0.0" (regexFind "^[0-9]+\\.[0-9]+\\.[0-9]+" $tag) }}
{{- fail (printf "\n\nPREFLIGHT: fid.mountSecrets is true but image tag %q is older than 8.0.0.\n\nMounted secrets are only supported by FID 8.x and later. A 7.x image cannot read them\nand will start without credentials, then never become ready.\n\nFix:      set  fid.mountSecrets: false\nBypass:   set  preflight.mountSecretsVersionCheck: false\n" $tag) }}
{{- end }}
{{- end }}
{{- end }}

{{- /* ------------------------------------------------------------------------------
     2. Immutable StatefulSet field drift.

     spec.selector and spec.volumeClaimTemplates cannot be changed in place. If a values
     change would alter either, `helm upgrade` fails partway through with a raw API error
     and the release is left in a half-applied state.

     Detect it up front and explain the recovery, rather than letting the API reject it.
     `lookup` returns nothing during `helm template`/`--dry-run`, so this is a no-op there.
     ------------------------------------------------------------------------------ */}}
{{- if ne $pf.immutableFieldCheck false }}
{{- $live := (lookup "apps/v1" "StatefulSet" .Release.Namespace (include "fid.fullname" .)) }}
{{- if $live }}
{{- $liveSel := ((($live.spec).selector).matchLabels) | default dict }}
{{- $wantSel := merge (dict "app.kubernetes.io/core-name" (include "fid.name" .)) (fromYaml (include "fid.selectorLabels" .)) }}
{{- if and $liveSel (ne (toString $liveSel) (toString $wantSel)) }}
{{- fail (printf "\n\nPREFLIGHT: this upgrade would change the StatefulSet's immutable selector.\n\n  live:    %v\n  render:  %v\n\nKubernetes rejects selector changes on an existing StatefulSet, so the upgrade would\nfail partway through.\n\nFix: recreate the StatefulSet, keeping the pods and PVCs alive:\n\n  kubectl delete statefulset %s -n %s --cascade=orphan\n  helm upgrade ...        # re-adopts the running pods\n\nBypass:   set  preflight.immutableFieldCheck: false\n" $liveSel $wantSel (include "fid.fullname" .) .Release.Namespace) }}
{{- end }}
{{- $liveSize := "" }}
{{- range (($live.spec).volumeClaimTemplates | default list) }}
{{- if eq .metadata.name "r1-pvc" }}{{ $liveSize = ((.spec.resources).requests).storage | toString }}{{ end }}
{{- end }}
{{- if and .Values.persistence.enabled $liveSize (ne $liveSize (.Values.persistence.size | toString)) }}
{{- fail (printf "\n\nPREFLIGHT: this upgrade would change the StatefulSet's immutable volumeClaimTemplate.\n\n  live persistence.size:   %s\n  requested:               %s\n\nvolumeClaimTemplates cannot be edited in place.\n\nTo actually grow the volumes (only works if the StorageClass has\nallowVolumeExpansion: true — check with `kubectl get sc`):\n\n  kubectl delete statefulset %s -n %s --cascade=orphan\n  kubectl patch pvc r1-pvc-%s-0 -n %s -p '{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"%s\"}}}}'\n  # ...repeat per replica, then:\n  helm upgrade ...\n\nBypass:   set  preflight.immutableFieldCheck: false\n" $liveSize (.Values.persistence.size | toString) (include "fid.fullname" .) .Release.Namespace (include "fid.fullname" .) .Release.Namespace (.Values.persistence.size | toString)) }}
{{- end }}
{{- end }}
{{- end }}

{{- /* ------------------------------------------------------------------------------
     3. persistence.storageClass sanity.

     The chart default is the literal string "default". That is a StorageClass NAME, not
     an instruction to use the cluster default — most clusters (EKS, GKE, kind) have no
     StorageClass called "default", so PVCs sit Pending forever with no obvious cause.
     AKS is the notable exception: it really does ship one named "default".

     Warn only when we can see the cluster and confirm it is missing.
     ------------------------------------------------------------------------------ */}}
{{- if ne $pf.storageClassCheck false }}
{{- if and .Values.persistence.enabled .Values.persistence.storageClass (ne .Values.persistence.storageClass "-") }}
{{- $classes := (lookup "storage.k8s.io/v1" "StorageClass" "" "") }}
{{- if and $classes $classes.items }}
{{- $want := .Values.persistence.storageClass }}
{{- $found := false }}
{{- range $classes.items }}{{ if eq .metadata.name $want }}{{ $found = true }}{{ end }}{{ end }}
{{- if not $found }}
{{- $names := list }}{{ range $classes.items }}{{ $names = append $names .metadata.name }}{{ end }}
{{- fail (printf "\n\nPREFLIGHT: persistence.storageClass is %q but no such StorageClass exists in this cluster.\n\nThis value is a StorageClass NAME, not a request for the cluster default. PVCs referencing\na non-existent class stay Pending indefinitely.\n\nAvailable: %s\n\nFix:      set persistence.storageClass to one of the above,\n          or to \"\" to use the cluster's default class.\nBypass:   set preflight.storageClassCheck: false\n" $want (join ", " $names)) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- end }}
