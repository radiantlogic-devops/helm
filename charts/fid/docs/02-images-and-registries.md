# 02 — Images and registries

Every image the chart renders is overridable — the main FID image, the metrics sidecar, all
five init containers, the hook Jobs, the migration CronJob and the `helm test` pods.

## The image dict

Each accepts the same five fields:

```yaml
repository: radiantone/fid
tag: "7.4.23"
digest: ""              # when set, WINS over tag
registry: ""            # falls back to global.imageRegistry
pullPolicy: IfNotPresent
```

## Airgapped / mirrored installs

One setting redirects everything:

```yaml
global:
  imageRegistry: "123456789012.dkr.ecr.us-west-2.amazonaws.com"
  imagePullSecrets:
    - name: mirror-creds
```

Every image the chart renders gets the prefix. Verified: with this set, **no image escapes
the mirror** — that assertion runs in CI.

> Before this was added, the init containers that gate FID startup were hardcoded to Docker
> Hub `:latest` with no override path, so a mirrored install was impossible.

Per-image override, if one thing lives elsewhere:

```yaml
helperImages:
  checkZk:
    registry: "other.registry.internal"
    repository: "mirrors/init-tools"
    digest: "sha256:aaaa...."
```

## What ships by default

All defaults are **first-party RadiantOne images**, matching helm-v8. Every one verified
**PUBLIC** (anonymous pull — no `regcred` needed) and tool-verified on a live cluster:

| Purpose | Image | Contains | Runs as |
|---|---|---|---|
| `check-zk`, `check-fid` | `radiantone/init-tools:latest` | `nc` | uid 65532 (nonroot) |
| `check-zk-readonly`, `migration` | `radiantone/curl:latest` | `curl`, `grep` | uid 0 |
| hook Jobs, migration CronJob | `radiantone/kubectl:latest` | `kubectl` | uid 1001 |
| `sysctl` init container | `busybox:latest` | Docker Official | uid 0 |
| metrics sidecar | `radiantone/fid-exporter:iddm-8.4.5` | exporter + Fluentd | uid 0 |

`radiantone/kubectl` is used for hooks deliberately: the stock hook scripts contain
commented-out lines that `curl` a kubectl binary down at runtime. Shipping an image that
already has it is both faster and safer.

### Do I need `imagePullSecrets`?

For the defaults above — **no**. All are anonymously pullable. You still need a pull secret
for:

- your own mirror, if it is authenticated (`global.imagePullSecrets`)
- `radiantone/fid` itself in some environments — check with:

```bash
TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:radiantone/fid:pull" | jq -r .token)
curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer $TOKEN" \
  https://registry-1.docker.io/v2/radiantone/fid/manifests/7.4.23
# 200 = public, 401/403 = needs credentials
```

> Docker **Official** images (alpine, busybox, postgres, mysql) live under `library/` in the
> registry API. Checking `library/alpine` reports public; checking `alpine` reports 401 and
> looks private when it is not.

## Pinning by digest

Recommended for production — tags are mutable, digests are not:

```yaml
image:
  repository: radiantone/fid
  digest: "sha256:002ac4c24f9bc131b0..."
helperImages:
  checkZk:
    digest: "sha256:...."
```

The chart renders `repository@sha256:...` and ignores `tag`.

## Upgrade note

Adopting the first-party defaults **changes the pod template**, so the first upgrade after
taking this chart version performs a rolling restart. To avoid it, pin the old values:

```yaml
helperImages:
  checkZk:          {repository: alpine,       tag: latest}
  checkZkReadonly:  {repository: alpine/curl,  tag: latest}
  checkFid:         {repository: alpine,       tag: latest}
  migration:        {repository: alpine/curl,  tag: latest}
  hooks:            {repository: alpine,       tag: ""}
```


## Pull secrets

Two independent ways to supply registry credentials; use either or both.

### `imagePullSecrets` — reference existing secrets

Names of `kubernetes.io/dockerconfigjson` Secrets you already have in the namespace:

```yaml
imagePullSecrets:
  - name: regcred
  - name: ecr-creds        # more than one is fine — all are attached to the pod
```

For a registry shared by every pod in the release, prefer `global.imagePullSecrets` — it is
merged into all of them (and deduplicated):

```yaml
global:
  imagePullSecrets:
    - name: mirror-creds
```

### `imageCredentials` — let the chart create the secret

When you would rather hand the chart a username/password than pre-create a Secret, it
renders a `dockerconfigjson` Secret named `regcred` for you:

```yaml
imageCredentials:
  enabled: true
  registry: docker.io          # any registry host — see the golden-image table below
  username: myuser
  password: mypass
  email: me@example.com
```

> `imageCredentials` puts the password in your values file. For anything sensitive, create
> the Secret out of band (or via [ESO](04-secrets-and-eso.md)) and use `imagePullSecrets`.

## Golden images — building your own from RadiantOne bases

Many customers rebuild the RadiantOne images (FID, the helper images, the exporter) on top
of a hardened internal base, then push them to their own registry. The chart supports this
without any template changes — point each image at your registry.

Everything at once, via the global prefix:

```yaml
global:
  imageRegistry: "registry.internal.example.com"
  imagePullSecrets:
    - name: internal-registry
```

`imageCredentials.registry` (and per-image `registry:`) accept any host, so common targets
all work:

| Registry | `registry` value |
|---|---|
| Docker Hub | `docker.io` |
| AWS ECR | `<acct>.dkr.ecr.<region>.amazonaws.com` |
| Azure ACR | `<name>.azurecr.io` |
| Google Artifact Registry | `<region>-docker.pkg.dev` |
| GitHub GHCR | `ghcr.io` |
| Harbor / Quay / Nexus | `harbor.example.com`, `quay.io`, `nexus.example.com:8443` |

Override an individual image (e.g. your golden FID, unchanged helpers from a mirror):

```yaml
global:
  imageRegistry: "registry.internal.example.com"   # applies to the helpers
image:
  registry: "123456789012.dkr.ecr.us-west-2.amazonaws.com"   # golden FID lives here
  repository: golden/fid
  tag: "7.4.23-hardened"
```

Per-image `registry:` wins over `global.imageRegistry`; a per-image `digest:` wins over its
`tag`. See the image dict at the top of this page.
