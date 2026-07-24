# 11 — Escape hatches

The chart must never be the reason you cannot do something. In rough order of preference:

## 1. Typed values

Most things are modelled directly — images, resources, securityContext, probes, scheduling.
Start here.

## 2. `extraX` collections

```yaml
extraInitContainers: []      # runs before FID
extraContainers: []          # extra sidecars
sidecars: []                 # same, legacy name
extraVolumes: []
extraVolumeMounts: []        # into the FID container
extraContainerVolumes: []
extraObjects: []             # arbitrary manifests attached to the release
```

Environment:

```yaml
env: {}                      # plain key/value
envValueFrom: {}             # valueFrom sources (fieldRef, secretKeyRef, ...)
envFromSecret: ""
envFromSecrets: []
envFromConfigMaps: []
envRenderSecret: {}
```

`extraObjects` entries are rendered through `tpl`, so they can reference release values:

```yaml
extraObjects:
  - apiVersion: monitoring.coreos.com/v1
    kind: ServiceMonitor
    metadata:
      name: "{{ include \"fid.fullname\" . }}"
    spec:
      selector:
        matchLabels: {app.kubernetes.io/instance: "{{ .Release.Name }}"}
      endpoints: [{port: exporter}]
```

## 3. `fid.podSpecPatch` — the no-ceiling primitive

Deep-merged over the rendered pod spec **last**, so it beats every typed value and every
security profile. It can set fields the chart has never heard of:

```yaml
fid:
  podSpecPatch:
    hostAliases:
      - ip: "10.0.0.9"
        hostnames: ["legacy-ldap.internal"]
    dnsConfig:
      options: [{name: ndots, value: "2"}]
    runtimeClassName: gvisor
    schedulerName: my-scheduler
    priorityClassName: system-cluster-critical
    terminationGracePeriodSeconds: 120
    automountServiceAccountToken: false
```

**Caveat:** list-valued fields (`containers`, `volumes`) are **replaced wholesale**, not
merged by name — this is Helm's `mergeOverwrite`, not kubectl's strategic merge. To adjust
one container, prefer the typed values; use the patch for fields the chart does not expose.

### The follower StatefulSet

The follower-only pods share the main pod's whole configuration surface (images, security
profile, probes, env, volumes, resources) and have their own patch:

```yaml
fid:
  followerOnly:
    podSpecPatch: {runtimeClassName: gvisor}   # falls back to fid.podSpecPatch when unset
```

## 4. Bring your own objects

```yaml
fid:
  existingSecret: "my-secret"      # chart renders no Secret
serviceAccount:
  create: false
  name: "my-sa"
podDisruptionBudget:
  enabled: false
hooks:
  rbac:
    rules: [...]                   # replaces the default rule set entirely
```

## 5. Turn the safety checks off

No check in this chart is mandatory:

```yaml
preflight:
  mountSecretsVersionCheck: false
  immutableFieldCheck: false
  storageClassCheck: false
```

## 6. Post-renderer

Anything left — `helm install --post-renderer ./kustomize-wrapper.sh`.

---

If none of these cover your case, that is a chart bug worth filing.
