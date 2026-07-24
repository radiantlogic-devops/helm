# 04 — Secrets and External Secrets Operator

## The key contract

The credentials Secret carries **five keys on this chart line** (verified against a live
install):

```
fid-root-username   fid-root-password   fid-license
zk-username         zk-password
```

`zk-username` is the one people forget. Omit it and ZooKeeper authentication fails in a way
that surfaces as an unrelated startup problem.

> The **v8** chart line has a sixth, `fid-admin-api-key`, which this FID version does not
> use. If one external secret serves both chart lines, include it there and leave it
> unmapped here — an extra key is harmless.

## Three ways to supply credentials

### 1. Chart-managed (default)

```yaml
fid:
  rootPassword: "..."
  license: "{rlib}..."
zk:
  password: "..."
```

Unset values are generated once and then **preserved across upgrades** — see
[10 — Upgrades](10-upgrades-and-rollback.md#credential-preservation).

### 2. Bring your own Secret

```yaml
fid:
  existingSecret: "my-fid-credentials"
```

The chart renders **no Secret**, and every consumer — the mounted volume and all four env
`secretKeyRef`s — resolves to yours. Works with Sealed Secrets, the Vault CSI driver, or a
Secret you created by hand.

### 3. External Secrets Operator

```yaml
externalSecret:
  enabled: true
  secretStoreRef:
    name: aws-secretsmanager
    kind: ClusterSecretStore
  remoteKey: "fid/prod/credentials"

fid:
  existingSecret: "rootcreds-<release>-fid"   # matches the default ESO target name
```

The default `target.name` is exactly what the chart's own Secret would have been called, so
those two line up automatically.

Requires ESO installed in the cluster. Works with any provider: AWS Secrets Manager, Vault,
OpenBao, GCP Secret Manager, Azure Key Vault, Conjur, Infisical.

#### Mapping differently-named external keys

```yaml
externalSecret:
  enabled: true
  secretStoreRef: {name: vault-backend, kind: ClusterSecretStore}
  data:
    - secretKey: fid-root-password
      remoteRef: {key: secret/data/fid, property: rootPassword}
    - secretKey: zk-username
      remoteRef: {key: secret/data/fid, property: zkUser}
    # ...all five
```

Or pull everything at once when names already match:

```yaml
externalSecret:
  dataFrom:
    - extract: {key: fid/prod/credentials}
```

### Why not a file-mount integration?

FID's credentials are consumed via `secretKeyRef` env vars and a mounted Secret volume.
Both need a **real Kubernetes Secret object**, so files-only approaches — the Vault Agent
Injector, or the CSI driver's file mode — cannot replace this. ESO's model (sync the
external value *into* a Secret) is the one that fits.

### Ordering caveat

ESO writes the Secret asynchronously. On a fresh install FID may restart a few times until
it appears. That is expected. If you need strict ordering, gate the release on ESO
readiness rather than expecting the chart to wait.

## Keeping the Secret on uninstall

```yaml
fid:
  retainSecret: true     # adds helm.sh/resource-policy: keep
```

Useful because a delete/reinstall cycle otherwise mints new credentials, stranding a
ZooKeeper ensemble whose ACLs still reference the old ones. Note a kept Secret must be
deleted by hand before the namespace is fully clean.

## Weak defaults — change them

`fid.rootPassword` defaults to `Welcome1234` and `zk.password` to `secret1234`. They ship
as working defaults so a bare `helm install` succeeds. Override both in any real
environment.
