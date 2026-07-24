{{/*
Shared route resolution for the ingress controllers (nginx / traefik / istio).

One `networking.routes` map drives all three, so switching controller does not mean
re-describing your topology. Each route resolves to a service + port on this release:

  controlPanel  <fullname>-ext    7070 / 7171   Classic Control Panel UI
  api           <fullname>-app    8089 / 8090   FID REST / HTTP API
  admin         <fullname>-admin  9100 / 9101   Admin REST service

Any route may be overridden per-field, and NEW routes can be added to the map without
touching templates — anything with {enabled, path, service, port} renders.

Returns a JSON list of resolved routes so callers can range over it.
*/}}
{{- define "fid.networking.routes" -}}
{{- $fullname := include "fid.fullname" . -}}
{{- $defaults := dict
  "controlPanel" (dict "path" "/"              "service" (printf "%s-ext" $fullname)   "port" 7070 "tlsPort" 7171 "order" 30)
  "api"          (dict "path" "/rest-service"  "service" (printf "%s-app" $fullname)   "port" 8089 "tlsPort" 8090 "order" 10)
  "admin"        (dict "path" "/admin-service" "service" (printf "%s-admin" $fullname) "port" 9100 "tlsPort" 9101 "order" 20)
-}}
{{- $out := list -}}
{{- range $name, $cfg := ((.Values.ingress).advanced).routes | default dict -}}
{{- if $cfg.enabled -}}
{{- $d := index $defaults $name | default dict -}}
{{- $svc := $cfg.service | default $d.service -}}
{{- if not $svc }}{{ fail (printf "networking.routes.%s is enabled but has no `service` and is not a known route (controlPanel|api|admin) - set service and port explicitly" $name) }}{{ end -}}
{{- $out = append $out (dict
      "name"    $name
      "path"    ($cfg.path     | default $d.path | default "/")
      "pathType" ($cfg.pathType | default "Prefix")
      "service" $svc
      "port"    (int ($cfg.port | default $d.port))
      "order"   (int ($cfg.order | default $d.order | default 50))
   ) -}}
{{- end -}}
{{- end -}}
{{- /* Controllers match in declaration order, so more specific paths must come first.
       Sort by `order` (lower first) using a zero-padded sort key, since sprig has no
       numeric sort. Defaults put /rest-service and /admin-service ahead of "/". */ -}}
{{- $keyed := dict -}}
{{- range $i, $r := $out -}}
{{- $k := printf "%03d-%02d" (int $r.order) (int $i) -}}
{{- $keyed = set $keyed $k $r -}}
{{- end -}}
{{- $sorted := list -}}
{{- range $k := (keys $keyed | sortAlpha) -}}
{{- $sorted = append $sorted (index $keyed $k) -}}
{{- end -}}
{{- toJson $sorted -}}
{{- end }}

{{/*
All hostnames for the ingress: networking.hostname plus networking.extraHostnames.
*/}}
{{- define "fid.networking.hosts" -}}
{{- $h := list -}}
{{- with ((.Values.ingress).advanced).hostname }}{{ $h = append $h . }}{{ end -}}
{{- range ((.Values.ingress).advanced).extraHostnames }}{{ $h = append $h . }}{{ end -}}
{{- toJson $h -}}
{{- end }}

{{/*
Guard: a controller is enabled but no hostname was given.

Every controller needs at least one host for HTTP routing. Failing here beats shipping an
Ingress with an empty host that silently swallows all traffic on the controller.
*/}}
{{- define "fid.networking.requireHost" -}}
{{- $hosts := fromJsonArray (include "fid.networking.hosts" .) -}}
{{- if not $hosts -}}
{{- fail "networking: a controller is enabled but networking.hostname is empty. Set networking.hostname (and optionally networking.extraHostnames)." -}}
{{- end -}}
{{- end }}

{{/*
Whether any advanced ingress controller (nginx/traefik/istio) is enabled. Used to suppress
the legacy single Ingress so the two never render at once.
*/}}
{{- define "fid.ingress.advancedActive" -}}
{{- $a := (.Values.ingress).advanced | default dict -}}
{{- if or (($a.nginx).enabled) (($a.traefik).enabled) (($a.istio).enabled) -}}
true
{{- end -}}
{{- end }}
