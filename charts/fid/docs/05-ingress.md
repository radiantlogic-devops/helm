# 05 — Ingress and external access

One `ingress.advanced` block drives **NGINX, Traefik and Istio** off a shared route map, so
switching controller does not mean redescribing your topology.

> The legacy single-Ingress `ingress:` block still work and are
> untouched. Use `ingress.advanced:` for anything new.


## `ingress:` legacy vs `ingress.advanced:`

`ingress.enabled` is the original single-Ingress mode. For multiple providers
(nginx/traefik/istio) and LDAPS TCP, use `ingress.advanced` — the same `routes` map drives
all three.

They never conflict: **enabling any `ingress.advanced` HTTP controller automatically
suppresses the legacy single Ingress**, so an existing `ingress.enabled: true` values file
keeps working until you opt into an advanced controller, at which point the advanced one
takes over. No flag to set, nothing to migrate.

```yaml
ingress:
  enabled: true            # legacy — renders UNLESS an advanced controller is on
  hosts: [{host: fid.example.com, paths: ["/"]}]
  advanced:
    hostname: fid.example.com
    routes: {controlPanel: {enabled: true}}
    nginx: {enabled: true}   # <- this now takes precedence; the legacy Ingress yields
```

`ingress.advanced.ldaps` / `.ldap` are TCP and independent of the HTTP Ingress above.

## Ports

| Protocol | Port | Service | Purpose |
|---|---|---|---|
| HTTP | 7070 / 7171 | `<release>-ext` | Classic Control Panel UI |
| HTTP | 8089 / 8090 | `<release>-app` | FID REST / HTTP API |
| HTTP | 9100 / 9101 | `<release>-admin` | Admin REST service |
| TCP | 2389 | `<release>-app` | LDAP (exposed as 389) |
| TCP | 2636 | `<release>-app` | LDAPS (exposed as 636) |

## Minimal example

```yaml
ingress:
  advanced:
  hostname: fid.example.com
  tls:
    enabled: true
    secretName: fid-tls
  routes:
    controlPanel: {enabled: true}     # "/"            -> :7070
    api:          {enabled: true}     # "/rest-service" -> :8089
  nginx:
    enabled: true
```

Swap `nginx` for `traefik` or `istio` — everything else stays the same.

## Routes are expandable

Add your own; anything with `{enabled, path, service, port}` renders:

```yaml
ingress:
  advanced:
  routes:
    myapp:
      enabled: true
      path: /my-app
      service: my-service
      port: 8080
      order: 5        # lower = matched first
```

`order` matters because controllers match in declaration order — specific paths must come
before `/`. The built-in defaults already do this (`api` 10, `admin` 20, `controlPanel` 30).

## LDAPS

```yaml
ingress:
  advanced:
  ldaps:
    enabled: true
    exposedPort: 636
    targetPort: 2636
```

**TLS is passed through, not terminated.** FID presents its own directory certificate.
Terminating at the edge breaks certificate-based (SASL EXTERNAL) client authentication —
which is usually the whole reason for exposing LDAPS.

Plain LDAP (`ingress.advanced.ldap`) is available but off by default: unencrypted directory
traffic.

## Controller-specific notes

### NGINX

```yaml
ingress:
  advanced:
  nginx:
    enabled: true
    ingressClassName: nginx
    backendProtocolHTTPS: false   # true if a route targets 7171/8090/9101
    annotations:
      nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    tcp:
      manageConfigMap: false
      controllerNamespace: ingress-nginx
      configMapName: tcp-services
```

**TCP in ingress-nginx is not part of the Ingress object.** The controller reads a
ConfigMap (`--tcp-services-configmap`) that lives in the **controller's** namespace. Two
consequences:

1. `manageConfigMap: true` makes this chart write it. Leave it **false** unless this
   release is the only thing managing that ConfigMap — ingress-nginx honours exactly one,
   so two charts writing it clobber each other.
2. The controller's Service must also publish the port. A ConfigMap entry alone does
   nothing if `:636` is not on the LoadBalancer.

Doing it by hand:

```yaml
# ConfigMap tcp-services in the ingress-nginx namespace
data:
  "636": "my-namespace/fid-app:2636"
```

`backendProtocolHTTPS` matters: without it nginx speaks HTTP to an HTTPS upstream and you
get 502s.

### Traefik

```yaml
ingress:
  advanced:
  traefik:
    enabled: true
    entryPoints:
      web: web
      websecure: websecure
      ldaps: ldaps
    middlewares: [redirect-https]
    # serversTransport: insecure-transport   # for self-signed FID certs
```

Renders an `IngressRoute` plus an `IngressRouteTCP` for LDAPS. The **entryPoints must
already exist on your Traefik installation** — ports are declared there, not here, and the
chart cannot create them.

`HostSNI(\`*\`)` is used for LDAPS because LDAPS clients typically send no SNI.

### Istio

```yaml
ingress:
  advanced:
  istio:
    enabled: true
    selector: {istio: ingressgateway}
    httpsRedirect: true
    # timeout: 60s
    # retries: {attempts: 3, perTryTimeout: 10s}
```

Renders a `Gateway` + `VirtualService` for HTTP, and a second pair using `protocol: TCP`
for LDAPS. TCP (not TLS with a `credentialName`) is deliberate — again, so FID terminates
TLS itself.

For TLS, `ingress.advanced.tls.secretName` becomes the gateway `credentialName` and **must live
in the istio-ingress namespace**, not this release's.

The istio-ingressgateway Service must also publish `:636`; a Gateway resource alone does
not open the port.

## NetworkPolicy enforcement

`hardened` and `paranoid` render a NetworkPolicy by default. `ingress.advanced.networkPolicy` is
tri-state: unset follows the profile, `true`/`false` always win.

**Creating the object does nothing unless your CNI enforces it.**

```bash
kubectl -n kube-system get ds aws-node -o jsonpath='{..args}'
# look for --enable-network-policy=true
```

- EKS + AWS VPC CNI: needs `--enable-network-policy=true`. With it false the object is
  accepted and **silently ignored** — this was the case on the cluster this chart was
  tested on, so the rules themselves remain unverified.
- Calico, Cilium, Antrea, Weave: enforce by default.

Egress is left unrestricted by default. FID needs DNS, ZooKeeper and every backend your
virtual view federates; guessing that set wrong fails in ways that are hard to diagnose.
