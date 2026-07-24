# 06 — Storage and persistence

```yaml
persistence:
  enabled: true
  storageClass: "auto"
  size: 10Gi
  accessModes: [ReadWriteOnce]
```

## `persistence.enabled` defaults to **false**

A clustered directory server defaults to ephemeral storage. Turn it on for anything you
care about.

## `storageClass` accepts four forms

| Value | Meaning |
|---|---|
| `"auto"` | Discover the best class present in the cluster |
| `"-"` | No class at all — disables dynamic provisioning |
| `""` | Omit the field; the cluster's default class applies |
| `<name>` | Use that class verbatim |

### The `"default"` trap

The historical default is the literal string `"default"` — a class **name**, not an
instruction to use the cluster default. Most clusters (EKS, GKE, kind) have no class called
`default`, so PVCs sit **Pending forever** with no obvious cause. AKS is the exception; it
really does ship one.

The chart now catches this before you hit it:

```
PREFLIGHT: persistence.storageClass is "default" but no such StorageClass exists.
Available: gp2, gp3, encrypted-gp3, ...
Bypass:   set preflight.storageClassCheck: false
```

### `"auto"`

Ranks what actually exists, best first:

1. default-annotated **and** encrypted **and** expandable
2. encrypted and expandable
3. default-annotated and expandable
4. expandable
5. the cluster's default-annotated class
6. nothing → omit the field and let the cluster decide

Encryption is inferred from the class name or its parameters (`encrypted: "true"`,
`kmsKeyId`, `encryptionKey`, `diskEncryptionSetID`), because Kubernetes has no portable
field for it.

Verified on a live EKS cluster: `auto` picked `encrypted-gp3` (encrypted, expandable) over
`gp3` (cluster default, but unencrypted).

**Caveat:** `auto` uses `lookup`, which is inert during `helm template`, `--dry-run` and
`helm lint` — an offline render omits the field. Check what it will really choose:

```bash
helm install fid radiantone/fid --dry-run=server -n my-ns -f values.yaml | grep storageClassName
```

## Resizing volumes

`volumeClaimTemplates` are **immutable**. Changing `persistence.size` on an existing
release cannot be applied in place, and the chart stops you:

```
PREFLIGHT: this upgrade would change the StatefulSet's immutable volumeClaimTemplate.
  live persistence.size:   100Gi
  requested:               500Gi
```

The recovery, which only works if the StorageClass has `allowVolumeExpansion: true`:

```bash
kubectl delete statefulset fid -n my-ns --cascade=orphan     # pods keep running
kubectl patch pvc r1-pvc-fid-0 -n my-ns \
  -p '{"spec":{"resources":{"requests":{"storage":"500Gi"}}}}'
# repeat per replica, then:
helm upgrade fid ... --set persistence.size=500Gi           # re-adopts the pods
```

Check expandability first:

```bash
kubectl get sc -o custom-columns=NAME:.metadata.name,EXPAND:.allowVolumeExpansion
```

Several tenant-scoped classes ship with `allowVolumeExpansion: false`, which makes online
resize impossible — you would need a migrate-and-replace instead.

## PVCs survive uninstall

`helm uninstall` does **not** remove PVCs created from `volumeClaimTemplates`:

```bash
helm uninstall fid -n my-ns
kubectl -n my-ns delete pvc -l app.kubernetes.io/name=fid
```

Leaving them stranded also keeps an autoscaled node alive.
