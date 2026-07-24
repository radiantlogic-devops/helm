# 03 — Security profiles

`security.profile` is a dial, not a cage.

```yaml
security:
  profile: vanilla    # vanilla | baseline | hardened | paranoid | custom
```

## What each profile does

| Control | vanilla | baseline | hardened | paranoid |
|---|---|---|---|---|
| `allowPrivilegeEscalation: false` | — | ✅ | ✅ | ✅ |
| `seccompProfile: RuntimeDefault` | — | ✅ | ✅ | ✅ |
| `runAsNonRoot` / uid 1000 | — | — | ✅ | ✅ |
| `capabilities.drop: [ALL]` | — | — | ✅ | ✅ |
| read-only rootfs (init containers) | — | — | ✅ | ✅ |
| read-only rootfs (**FID container**) | — | — | — | ✅ |
| `automountServiceAccountToken: false` | — | — | ✅ | ✅ |
| NetworkPolicy rendered | — | — | ✅ | ✅ |

- **`vanilla`** is the default and is a fully supported destination — byte-for-byte what
  the chart has always rendered. If you want root and no restrictions, stay here.
- **`custom`** applies no preset at all.

## Profiles supply defaults only — you always win

```yaml
security:
  profile: hardened
securityContext:
  runAsUser: 0          # this image insists on root
  runAsNonRoot: false
```

→ a hardened pod that still runs as root. Verified in CI.

`fid.podSpecPatch` is applied *after* everything, so it beats even that.

To **remove** a field a profile sets rather than change it, use `profile: custom`.

## Verified

`hardened` is validated on a live cluster against FID 7.4.23: pod runs as uid/gid 1000
with `allowPrivilegeEscalation: false`, all capabilities dropped and RuntimeDefault
seccomp; the cluster forms, a leader is elected and all bundled tests pass with zero
restarts.

## Not verified — read before using

- **`paranoid`**'s read-only rootfs on the FID container is **untested**. FID writes under
  `/opt/radiantone` at runtime, so it needs writable mounts for every such path. Work them
  out in a test namespace with `extraVolumes` / `extraVolumeMounts` first.
- **NetworkPolicy rules** are unverified. The chart renders a valid policy, but the cluster
  it was tested on (EKS with the AWS VPC CNI) had enforcement **off**, so nothing exercised
  the rules. See [05 — Ingress](05-ingress.md#networkpolicy-enforcement).

## The exporter needs root — and the chart handles it

The metrics sidecar tails FID's log files, which requires uid 0. Under `hardened` that
collides with pod-level `runAsNonRoot: true`, and kubelet fails the pod with:

```
Error: container's runAsUser breaks non-root policy
```

The chart detects a resolved `runAsUser: 0` on that container and emits
`runAsNonRoot: false` alongside it, which overrides the pod-level policy. You do not need to
know this. An explicit `metrics.securityContext.runAsNonRoot` still wins if you want the
strict behaviour.

## Switching profiles is safe to roll back

Profiles only touch mutable pod-template fields, so `helm rollback` reverses them exactly.
Anything not rollback-safe (NetworkPolicy, RBAC scope) is a separate toggle.
