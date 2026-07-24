# 14 — Environment variables, volumes and sidecars

Everything for injecting configuration and attaching extra containers/volumes to the FID
pod. All of these are additive — unset, they render nothing.

## Environment variables

### `env` — plain key/value

```yaml
env:
  INSTALL_SAMPLES: "false"
  FID_SERVER_JOPTS: "-Xms2g -Xmx4g"
  AWS_REGION: us-east-1
```

Rendered as `name: <key>` / `value: <value>` on the FID container. Both key and value are
run through `tpl`, so they may reference other values (`"{{ .Release.Namespace }}"`).

### `envValueFrom` — valueFrom sources

For values that come from a ConfigMap key, Secret key, or the downward API. The key name is
templated; the value is a raw
[EnvVarSource](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.19/#envvarsource-v1-core):

```yaml
envValueFrom:
  DB_PASSWORD:
    secretKeyRef:
      name: my-db-secret
      key: password
  POD_IP:
    fieldRef:
      fieldPath: status.podIP
```

Renders as:

```yaml
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef: {name: my-db-secret, key: password}
```

### Pulling whole ConfigMaps / Secrets into the environment

| Key | Type | Purpose |
|---|---|---|
| `envFromSecret` | string | Name of one Secret; all its keys become env vars. Templated. |
| `envFromSecrets` | list | Several Secrets, each `{name, optional}`. Names templated. |
| `envFromConfigMaps` | list | Several ConfigMaps, each `{name, optional}`. Names templated. |
| `envRenderSecret` | map | Key/values the chart renders into a **new** Secret, then loads. For auth tokens you want managed by the release. |

```yaml
envFromSecret: "fid-shared-env"

envFromSecrets:
  - {name: "auth-tokens", optional: true}

envFromConfigMaps:
  - {name: "fid-tuning"}

envRenderSecret:
  API_TOKEN: "s3cr3t"          # chart creates a Secret and envFrom's it
```

> For **credentials** prefer [ESO or an existing Secret](04-secrets-and-eso.md) over
> `envRenderSecret`, which puts the value in your values file.

## Init containers

```yaml
extraInitContainers:
  - name: wait-for-db
    image: busybox:1.36
    command: ["sh", "-c", "until nc -z db 5432; do sleep 2; done"]
```

Evaluated as a template, so entries may reference release values. Runs before FID, in
addition to the chart's own init containers (see [02 — Images](02-images-and-registries.md)).

## Volumes and mounts

Three separate knobs, because they attach at different scopes:

| Key | Attaches to | Use for |
|---|---|---|
| `extraVolumes` | the pod | any volume the FID container should mount |
| `extraVolumeMounts` | the **FID container** | mount points for the volumes above |
| `extraContainerVolumes` | the pod, for **init containers only** | volumes an init container needs but FID does not |

Typical case — mount a keystore/truststore to enable TLS:

```yaml
extraVolumes:
  - name: fid-keystore
    secret:
      defaultMode: 288
      secretName: fid-keystore
  - name: fid-truststore
    secret:
      defaultMode: 288
      secretName: fid-truststore

extraVolumeMounts:
  - {name: fid-keystore,   mountPath: /certs/keystore,   readOnly: true}
  - {name: fid-truststore, mountPath: /certs/truststore, readOnly: true}
```

An init-container-only volume (not mounted into FID):

```yaml
extraContainerVolumes:
  - name: bootstrap-scripts
    emptyDir: {}
```

> The `paranoid` [security profile](03-security-profiles.md) sets a read-only root
> filesystem on the FID container; use `extraVolumes` + `extraVolumeMounts` (emptyDir) for
> every path FID writes to.

## Sidecar containers

```yaml
sidecars:
  - name: audit-forwarder
    image: my/audit:1.2
    imagePullPolicy: Always
    ports:
      - {name: audit, containerPort: 1234}
```

Additional long-running containers in the FID pod. For arbitrary containers with no chart
opinion, `extraContainers` is the newer, tpl-rendered equivalent — see
[11 — Escape hatches](11-escape-hatches.md).

## Lifecycle scripts

### `postInstall` — run once, after the first install

```yaml
postInstall:
  enabled: true
  leaderOnly: true            # run on fid-0 only
  script: |
    /opt/radiantone/vds/bin/vdsconfig.sh set-property \
      -name agentsApiServerEndpoint -value "https://example.com/example"
```

### `postStart` — container lifecycle postStart hook

```yaml
postStart:
  enabled: true
  leaderOnly: true
  script: |
    echo "container started"
```

`postStart` runs on every container start (not just first install); `postInstall` runs once
after the initial install. Use `postInstall` for one-time configuration and `postStart` for
things that must re-run on every restart.

## Precedence with `fid.podSpecPatch`

All of the above are typed conveniences. Anything not modelled here — or a field you need to
set on a container the chart owns — goes through `fid.podSpecPatch`, applied last. See
[11 — Escape hatches](11-escape-hatches.md).
