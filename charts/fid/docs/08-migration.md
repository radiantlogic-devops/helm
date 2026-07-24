# 08 — Migration

Seed a new cluster from an existing `export.zip` at first install.

## Legacy: a plain URL

```yaml
fid:
  migration:
    url: "https://artifacts.example.com/fid/export.zip"
    script: "https://artifacts.example.com/fid/configure_fid.sh"   # optional
```

An init container downloads the artifact into `/migrations` before FID starts.

## Advanced: other sources

```yaml
fid:
  migration:
    advanced:
      enabled: true
      source:
        type: s3            # http | s3 | gcs | azure | git | db
        s3:
          bucket: my-exports
          key: fid/export.zip
          region: us-west-2
          auth:
            accessKeyIdSecretRef:     {name: aws-creds, key: access-key-id}
            secretAccessKeySecretRef: {name: aws-creds, key: secret-access-key}
```

### Precedence is exclusive

- `advanced.enabled: true` → **only** the advanced block is read; `url`/`script` ignored.
- `advanced.enabled: false` → **only** the legacy `url`/`script`.

Same rule as helm-v8, so a values file moves between chart lines.

## Sources

| type | Needs | Default image |
|---|---|---|
| `http` | `source.http.url` | `radiantone/curl:latest` |
| `s3` | `bucket`, `key` | `amazon/aws-cli:2.15.40` |
| `gcs` | `bucket`, `object` | `google-cloud-cli:slim` |
| `azure` | `accountName`, `container`, `blob` | `azcopy:10.24.0` |
| `git` | `repo`, `ref`, `path` | `alpine/git:latest` |
| `db` | `driver`, `host`, `database`, `query` | `postgres:16-alpine` / `mysql:8.3` |

All images are overridable and resolve through `fid.image`, so `global.imageRegistry` and
digest pinning apply:

```yaml
fid:
  migration:
    advanced:
      image:
        s3: {repository: my-mirror/aws-cli, tag: "2.15.40"}
```

## Credentials are never literals

Every provider reads credentials from a Secret you already have:

```yaml
# S3 with IRSA — no secret needed at all
s3:
  bucket: my-exports
  key: fid/export.zip
  auth: {irsa: true}

# Azure with managed identity
azure:
  accountName: mystorage
  container: exports
  blob: export.zip
  auth: {managedIdentity: true}

# Git over SSH
git:
  repo: "git@github.com:myorg/fid-config.git"
  ref: main
  path: exports/export.zip
  auth:
    sshKeySecretRef:          {name: git-ssh-key}
    knownHostsConfigMapRef:   {name: git-known-hosts, key: known_hosts}

# Git over HTTPS with a token
git:
  repo: "https://github.com/myorg/fid-config.git"
  auth:
    usernameSecretRef: {name: git-creds, key: username}
    tokenSecretRef:    {name: git-creds, key: token}
```

This composes with [ESO](04-secrets-and-eso.md): land cloud credentials in a Secret via
ESO, reference the Secret here, and nothing sensitive touches `values.yaml`.

Without `knownHostsConfigMapRef`, SSH falls back to `StrictHostKeyChecking=accept-new` —
trust-on-first-use. Supply known hosts for anything production.

## Database source

```yaml
db:
  driver: postgres        # or mysql
  host: db.example.com
  port: 5432
  database: fidconfig
  query: "SELECT payload FROM exports ORDER BY created_at DESC LIMIT 1"
  outputEncoding: base64  # or raw
  auth:
    usernameSecretRef: {name: db-creds, key: username}
    passwordSecretRef: {name: db-creds, key: password}
```

`outputEncoding: base64` decodes the query result into `export.zip`; `raw` copies it
verbatim.

## Scheduled export CronJob

Separate from import:

```yaml
cronjob:
  migration:
    enabled: true
    schedule: "0 0 * * *"
    s3: "s3://fid-exports/nightly"
```

## Migration runs on first install only

The init container writes into `/migrations`; FID imports it during initial setup. It does
not re-import on every restart. To re-run, reinstall or drive the import manually.
