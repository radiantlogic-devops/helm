{{- /*
_fluentd_helpers.tpl

Purpose:
1. ES / OS => <logName>.log-<clusterName>
2. Splunk => index => aggregator.index if set; else <logName> minus ".log"
3. Loki => merges default label service_name => "<logName>.log" with aggregator.extraLabels
4. sumologic, s3 => no special forced index logic
5. source => multiline unless .parse block is defined
6. match => enumerates aggregator partials

Version: 1.0.0
Last Modified: 2025-01-27
Tested with Fluentd versions: 1.18.0
*/ -}}

{{- /*
Convert string to lowercase
*/ -}}
{{- define "fid.fluentd.toLowerCase" -}}
{{- . | lower -}}
{{- end -}}

{{- /*
Strip .log suffix from index names
*/ -}}
{{- define "fid.fluentd.stripDotLog" -}}
{{- $val := . -}}
{{- if hasSuffix ".log" $val -}}
{{- substr 0 (sub (len $val) 4) $val -}}
{{- else -}}
{{- $val -}}
{{- end -}}
{{- end -}}

{{- /*
Aggregator Key Definitions and Validation
*/ -}}
{{- define "fid.fluentd.aggregatorKeys" -}}
{
  "elasticsearch": {
    "required": [],
    "allowed": [
      "type", "name", "host", "port", "hosts", "scheme", "user", "password", "path",
      "cloud_id", "cloud_auth",
      "logstash_format", "logstash_prefix", "logstash_dateformat", "logstash_prefix_separator",
      "index_name", "target_index_key", "target_type_key", "type_name",
      "id_key", "parent_key", "routing_key", "write_operation",
      "pipeline", "template_name", "template_file", "templates", "template_overwrite",
      "max_retry_putting_template", "fail_on_putting_template_retry_exceed",
      "enable_ilm", "ilm_policy", "ilm_policy_id", "ilm_policy_overwrite", "application_name",
      "reconnect_on_error", "reload_connections", "reload_on_failure",
      "resurrect_after", "request_timeout", "max_retry_get_es_version",
      "time_key", "time_key_format", "time_key_exclude_timestamp", "utc_index", "include_timestamp",
      "include_tag_key", "tag_key", "remove_keys", "remove_keys_on_update", "remove_keys_on_update_key",
      "suppress_type_name", "prefer_oj_serializer", "emit_error_for_missing_id",
      "buffer", "ssl",
      "ssl_verify", "ca_file", "client_cert", "client_key", "client_key_pass", "ssl_version"
    ]
  },
  "opensearch": {
    "required": [],
    "allowed": [
      "type", "name", "host", "port", "hosts", "scheme", "user", "password", "path",
      "logstash_format", "logstash_prefix", "logstash_dateformat",
      "index_name", "target_index_key", "type_name",
      "id_key", "parent_key", "routing_key", "write_operation",
      "pipeline", "template_name", "template_file", "template_overwrite",
      "customize_template", "compression_level",
      "reconnect_on_error", "reload_connections", "reload_on_failure", "request_timeout",
      "time_key", "time_key_format", "include_timestamp",
      "include_tag_key", "tag_key", "remove_keys",
      "suppress_doc_wrap", "suppress_type_name",
      "buffer", "ssl",
      "ssl_verify", "ca_file", "client_cert", "client_key", "client_key_pass", "ssl_version"
    ]
  },
  "splunk_hec": {
    "required": ["hec_host", "hec_port", "hec_token"],
    "allowed": [
      "type", "name", "hec_host", "hec_port", "hec_token", "protocol",
      "insecure_ssl", "ca_file", "ca_path", "client_cert", "client_key", "ssl_ciphers",
      "index", "index_key", "host", "host_key", "source", "source_key",
      "sourcetype", "sourcetype_key",
      "data_type", "metric_name_key", "metric_value_key",
      "metrics_from_event", "use_ack", "channel", "ack_retry", "ack_retry_limit",
      "use_fluentd_time", "time_as_integer",
      "fields", "idle_timeout", "read_timeout",
      "raw", "keep_keys", "coerce_to_utf8", "non_utf8_replacement_string",
      "buffer", "ssl"
    ]
  },
  "loki": {
    "required": ["url"],
    "allowed": [
      "type", "name", "url", "username", "password", "tenant",
      "insecure_tls", "ca_cert", "cert", "key",
      "ciphers", "min_version", "compress", "custom_headers",
      "bearer_token_file",
      "extra_labels", "extraLabels", "include_thread_label",
      "drop_single_key", "remove_keys", "line_format",
      "extract_kubernetes_labels",
      "buffer", "ssl"
    ]
  },
  "sumologic": {
    "required": ["endpoint"],
    "allowed": [
      "type", "name", "endpoint", "verify_ssl", "ca_path",
      "source_name", "source_name_key", "source_host", "source_host_key",
      "source_category", "source_category_key", "source_category_prefix",
      "source_category_replace_dash",
      "data_type", "metric_data_type", "metrics_data_type", "metric_data_format",
      "log_format", "json_merge",
      "log_key", "add_timestamp", "add_timestamp_key", "timestamp_key",
      "compress", "compress_encoding",
      "proxy_uri", "proxy_cert", "proxy_key",
      "disable_cookies", "open_timeout", "send_timeout", "receive_timeout",
      "delimiter", "custom_fields", "custom_dimensions", "sumo_client",
      "use_internal_retry", "retry_timeout", "retry_max_times",
      "retry_min_interval", "retry_max_interval", "max_request_size",
      "buffer", "ssl"
    ]
  },
  "s3": {
    "required": ["s3_bucket", "s3_region"],
    "allowed": [
      "type", "name", "s3_bucket", "s3_region", "s3_endpoint",
      "aws_key_id", "aws_sec_key", "assume_role_credentials",
      "role_arn", "role_session_name", "external_id",
      "path", "s3_object_key_format", "store_as",
      "format", "format_json_flatten", "compression",
      "use_ssl", "ssl_verify_peer", "force_path_style",
      "use_server_side_encryption", "ssekms_key_id",
      "sse_customer_algorithm", "sse_customer_key", "sse_customer_key_md5",
      "acl", "grant_full_control", "grant_read", "grant_read_acp", "grant_write_acp",
      "storage_class", "auto_create_bucket", "overwrite",
      "time_slice_format", "utc", "hex_random_length", "index_format",
      "check_object", "check_bucket", "warn_for_delay",
      "buffer", "ssl",
      "bucket", "region"
    ]
  },
  "azure_event_hubs": {
    "required": ["connection_string", "hub_name"],
    "allowed": [
      "type", "name", "connection_string", "hub_name",
      "include_tag", "include_time", "tag_time_name",
      "expiry_interval", "message_properties",
      "batch", "max_batch_size",
      "proxy_addr", "proxy_port",
      "open_timeout", "read_timeout",
      "ssl_verify", "coerce_to_utf8", "non_utf8_replacement_string",
      "print_records",
      "buffer"
    ]
  },
  "opentelemetry": {
    "required": [],
    "allowed": [
      "type", "name", "endpoint", "host", "port",
      "protocol", "service_name", "service_name_key",
      "resource_attributes", "resource_attributes_key",
      "headers", "headers_key",
      "insecure", "insecure_tls",
      "ca_file", "ca_path", "cert_file", "cert", "key_file", "key",
      "timeout", "open_timeout", "read_timeout",
      "compression", "compression_level",
      "format", "json_array", "include_tag_key", "tag_key",
      "remove_keys", "add_timestamp", "timestamp_key",
      "buffer", "ssl"
    ]
  }
}
{{- end -}}

{{- /*
Helper function to get aggregator name
*/ -}}
{{- define "fid.fluentd.getAggregatorName" -}}
{{- $agg := . }}
{{- if hasKey $agg "name" }}
  {{- $agg.name }}
{{- else }}
  {{- printf "%s-%s" $agg.type (randAlpha 5 | lower) }}
{{- end }}
{{- end -}}

{{- /*
Validate aggregator configuration
*/ -}}
{{- define "fid.checkAggregatorKeys" -}}
{{- $aggregator := .aggregator -}}
{{- $aggType := .aggType -}}
{{- $allKeys := include "fid.fluentd.aggregatorKeys" $ | fromYaml -}}
{{- $typeMap := index $allKeys $aggType -}}

{{- if not $typeMap }}
{{- fail (printf "Unknown aggregator type '%s'." $aggType) -}}
{{- end }}

{{- $allowedKeys := index $typeMap "allowed" -}}
{{- $requiredKeys := index $typeMap "required" -}}

{{- /* Special validation for elasticsearch/opensearch - either host+port OR hosts OR cloud_id */ -}}
{{- if or (eq $aggType "elasticsearch") (eq $aggType "opensearch") }}
  {{- if not (or (and (hasKey $aggregator "host") (hasKey $aggregator "port")) (hasKey $aggregator "hosts") (hasKey $aggregator "cloud_id")) }}
    {{- fail (printf "Aggregator of type '%s' requires either 'host' and 'port', OR 'hosts', OR 'cloud_id'." $aggType) -}}
  {{- end }}
{{- /* Special validation for opentelemetry - either endpoint OR host+port */ -}}
{{- else if eq $aggType "opentelemetry" }}
  {{- if not (or (hasKey $aggregator "endpoint") (and (hasKey $aggregator "host") (hasKey $aggregator "port"))) }}
    {{- fail (printf "Aggregator of type '%s' requires either 'endpoint' OR both 'host' and 'port'." $aggType) -}}
  {{- end }}
{{- else }}
  {{- range $req := $requiredKeys }}
  {{- if not (hasKey $aggregator $req) -}}
  {{- fail (printf "Aggregator of type '%s' is missing required key '%s'." $aggType $req) -}}
  {{- end }}
  {{- end }}
{{- end }}

{{- range $key, $value := $aggregator }}
{{- if not (has $key $allowedKeys) -}}
{{- fail (printf "Unsupported key '%s' found for aggregator type '%s'. Allowed keys: %v" $key $aggType $allowedKeys) -}}
{{- end }}
{{- end }}
{{- end -}}

{{- /*
Common buffer configuration
*/ -}}
{{- define "fid.fluentd.buffer" -}}
{{- $config := .config -}}
{{- $defaultPath := .defaultPath | default "/var/log/fluentd-buffers/kubernetes.system.buffer" -}}
<buffer>
  @type file
  path {{ $config.path | default $defaultPath }}
  flush_mode {{ $config.flush_mode | default "interval" }}
  retry_type {{ $config.retry_type | default "exponential_backoff" }}
  flush_thread_count {{ $config.flush_thread_count | default 2 }}
  flush_interval {{ $config.flush_interval | default "5s" }}
  retry_forever {{ $config.retry_forever | default true }}
  retry_max_interval {{ $config.retry_max_interval | default "30" }}
  chunk_limit_size {{ $config.chunk_limit_size | default "2M" }}
  queue_limit_length {{ $config.queue_limit_length | default "8" }}
  overflow_action {{ $config.overflow_action | default "block" }}
</buffer>
{{- end -}}

{{- /*
SSL configuration for Elasticsearch/OpenSearch
Both plugins use identical SSL parameter names
Supports both flat and nested SSL configuration (for EOC compatibility)
*/ -}}
{{- define "fid.fluentd.ssl.elasticsearch" -}}
{{- $agg := .aggregator -}}
{{- $scheme := .scheme | default "http" -}}
{{- /* Apply SSL settings if scheme is https OR if explicit SSL parameters are provided */ -}}
{{- if or (eq $scheme "https") (hasKey $agg "ssl_verify") (hasKey $agg "ca_file") (hasKey $agg "client_cert") (hasKey $agg "ssl") }}
  {{- /* ssl_verify: Check flat parameter first, then nested, then default for https */ -}}
  {{- if hasKey $agg "ssl_verify" }}
ssl_verify {{ $agg.ssl_verify }}
  {{- else if hasKey $agg "ssl" }}
    {{- if kindIs "map" $agg.ssl }}
      {{- if hasKey $agg.ssl "verify" }}
ssl_verify {{ $agg.ssl.verify }}
      {{- else if hasKey $agg.ssl "enabled" }}
        {{- if $agg.ssl.enabled }}
ssl_verify true
        {{- end }}
      {{- end }}
    {{- end }}
  {{- else if eq $scheme "https" }}
ssl_verify true
  {{- end }}

  {{- /* CA certificate - support both flat and nested */ -}}
  {{- if hasKey $agg "ca_file" }}
ca_file {{ $agg.ca_file }}
  {{- else if hasKey $agg "ssl" }}
    {{- if kindIs "map" $agg.ssl }}
      {{- if hasKey $agg.ssl "ca_path" }}
ca_file {{ $agg.ssl.ca_path }}
      {{- else if hasKey $agg.ssl "ca_file" }}
ca_file {{ $agg.ssl.ca_file }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{- /* Client certificate authentication - support both flat and nested */ -}}
  {{- if hasKey $agg "client_cert" }}
client_cert {{ $agg.client_cert }}
  {{- else if hasKey $agg "ssl" }}
    {{- if kindIs "map" $agg.ssl }}
      {{- if hasKey $agg.ssl "cert_path" }}
client_cert {{ $agg.ssl.cert_path }}
      {{- else if hasKey $agg.ssl "client_cert" }}
client_cert {{ $agg.ssl.client_cert }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{- if hasKey $agg "client_key" }}
client_key {{ $agg.client_key }}
  {{- else if hasKey $agg "ssl" }}
    {{- if kindIs "map" $agg.ssl }}
      {{- if hasKey $agg.ssl "key_path" }}
client_key {{ $agg.ssl.key_path }}
      {{- else if hasKey $agg.ssl "client_key" }}
client_key {{ $agg.ssl.client_key }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{- if hasKey $agg "client_key_pass" }}
client_key_pass {{ $agg.client_key_pass }}
  {{- else if hasKey $agg "ssl" }}
    {{- if kindIs "map" $agg.ssl }}
      {{- if hasKey $agg.ssl "key_passphrase" }}
client_key_pass {{ $agg.ssl.key_passphrase }}
      {{- else if hasKey $agg.ssl "client_key_pass" }}
client_key_pass {{ $agg.ssl.client_key_pass }}
      {{- end }}
    {{- end }}
  {{- end }}

  {{- /* SSL version */ -}}
  {{- if hasKey $agg "ssl_version" }}
ssl_version {{ $agg.ssl_version }}
  {{- else if hasKey $agg "ssl" }}
    {{- if kindIs "map" $agg.ssl }}
      {{- if hasKey $agg.ssl "version" }}
ssl_version {{ $agg.ssl.version }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end -}}

{{- /*
SSL configuration for Splunk HEC
Splunk uses 'insecure_ssl' (opposite of ssl_verify)
*/ -}}
{{- define "fid.fluentd.ssl.splunk" -}}
{{- $agg := . -}}
{{- $protocol := $agg.protocol | default "https" -}}
{{- /* insecure_ssl: opposite of ssl_verify */ -}}
{{- if hasKey $agg "insecure_ssl" }}
insecure_ssl {{ $agg.insecure_ssl }}
{{- else if hasKey $agg "ssl_verify" }}
insecure_ssl {{ not $agg.ssl_verify }}
{{- else if hasKey $agg "ssl" }}
  {{- if kindIs "map" $agg.ssl }}
    {{- if hasKey $agg.ssl "verify" }}
insecure_ssl {{ not $agg.ssl.verify }}
    {{- end }}
  {{- end }}
{{- end }}
{{- /* CA certificate */ -}}
{{- if hasKey $agg "ca_file" }}
ca_file {{ $agg.ca_file }}
{{- end }}
{{- if hasKey $agg "ca_path" }}
ca_path {{ $agg.ca_path }}
{{- end }}
{{- /* Client certificate authentication */ -}}
{{- if hasKey $agg "client_cert" }}
client_cert {{ $agg.client_cert }}
{{- end }}
{{- if hasKey $agg "client_key" }}
client_key {{ $agg.client_key }}
{{- end }}
{{- end -}}

{{- /*
SSL configuration for Loki
Loki uses 'insecure_tls' (opposite of ssl_verify) and 'ca_cert' (not ca_file)
*/ -}}
{{- define "fid.fluentd.ssl.loki" -}}
{{- $agg := . -}}
{{- /* Check if SSL configuration is needed */ -}}
{{- $url := $agg.url | default "" -}}
{{- $isHttps := hasPrefix "https://" $url -}}
{{- /* Check if ssl exists and is a dict before accessing its properties */ -}}
{{- $sslEnabled := false -}}
{{- if hasKey $agg "ssl" -}}
  {{- if kindIs "map" $agg.ssl -}}
    {{- if hasKey $agg.ssl "enabled" -}}
      {{- $sslEnabled = $agg.ssl.enabled -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- /* Always output insecure_tls for Loki - default to true (permissive) */ -}}
{{- if hasKey $agg "insecure_tls" }}
insecure_tls {{ $agg.insecure_tls }}
{{- else if hasKey $agg "ssl" }}
  {{- if kindIs "map" $agg.ssl }}
    {{- if hasKey $agg.ssl "verify" }}
insecure_tls {{ not $agg.ssl.verify }}
    {{- else if $isHttps }}
insecure_tls false
    {{- else }}
insecure_tls true
    {{- end }}
  {{- else if $isHttps }}
insecure_tls false
  {{- else }}
insecure_tls true
  {{- end }}
{{- else if $isHttps }}
  {{- /* For HTTPS URLs, default to secure (false) */ -}}
insecure_tls false
{{- else }}
  {{- /* Default for HTTP or when not specified: permissive (true) */ -}}
insecure_tls true
{{- end }}
{{- if or $isHttps (hasKey $agg "ca_cert") $sslEnabled }}
  {{- /* CA certificate - Loki uses 'ca_cert' not 'ca_file' */ -}}
  {{- if hasKey $agg "ca_cert" }}
ca_cert {{ $agg.ca_cert }}
  {{- else if hasKey $agg "ssl" }}
    {{- if kindIs "map" $agg.ssl }}
      {{- if hasKey $agg.ssl "ca_path" }}
ca_cert {{ $agg.ssl.ca_path }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- /* Client certificate authentication */ -}}
  {{- if hasKey $agg "client_cert" }}
client_cert {{ $agg.client_cert }}
  {{- else if hasKey $agg "ssl" }}
    {{- if kindIs "map" $agg.ssl }}
      {{- if hasKey $agg.ssl "cert_path" }}
client_cert {{ $agg.ssl.cert_path }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if hasKey $agg "client_key" }}
client_key {{ $agg.client_key }}
  {{- else if hasKey $agg "ssl" }}
    {{- if kindIs "map" $agg.ssl }}
      {{- if hasKey $agg.ssl "key_path" }}
client_key {{ $agg.ssl.key_path }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end -}}

{{- /*
SSL configuration for Sumologic
Sumologic uses 'verify_ssl' (not ssl_verify)
Plugin default for verify_ssl is true, so only output when user wants to change it
*/ -}}
{{- define "fid.fluentd.ssl.sumologic" -}}
{{- $agg := . -}}
{{- /* verify_ssl: Only output if user explicitly sets it */ -}}
{{- if hasKey $agg "verify_ssl" }}
verify_ssl {{ $agg.verify_ssl }}
{{- else if hasKey $agg "ssl" }}
  {{- if kindIs "map" $agg.ssl }}
    {{- if hasKey $agg.ssl "verify" }}
verify_ssl {{ $agg.ssl.verify }}
    {{- end }}
  {{- end }}
{{- end }}
{{- /* CA path - if supported */ -}}
{{- if hasKey $agg "ca_path" }}
ca_path {{ $agg.ca_path }}
{{- else if hasKey $agg "ssl" }}
  {{- if kindIs "map" $agg.ssl }}
    {{- if hasKey $agg.ssl "ca_path" }}
ca_path {{ $agg.ssl.ca_path }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end -}}

{{- /*
SSL configuration for S3 - S3 uses IAM roles/keys, not SSL certs directly
*/ -}}
{{- define "fid.fluentd.ssl.s3" -}}
{{- /* S3 doesn't use SSL certificates directly, it uses AWS IAM */ -}}
{{- end -}}

{{- /*
SSL configuration for OpenTelemetry
OpenTelemetry uses 'insecure' or 'insecure_tls' (opposite of ssl_verify)
and supports ca_file, cert_file, key_file
*/ -}}
{{- define "fid.fluentd.ssl.opentelemetry" -}}
{{- $agg := . -}}
{{- $endpoint := $agg.endpoint | default "" -}}
{{- $isHttps := or (hasPrefix "https://" $endpoint) (hasPrefix "grpcs://" $endpoint) -}}
{{- $sslEnabled := false -}}
{{- if hasKey $agg "ssl" -}}
  {{- if kindIs "map" $agg.ssl -}}
    {{- if hasKey $agg.ssl "enabled" -}}
      {{- $sslEnabled = $agg.ssl.enabled -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- /* insecure/insecure_tls: opposite of ssl_verify */ -}}
{{- if hasKey $agg "insecure" }}
insecure {{ $agg.insecure }}
{{- else if hasKey $agg "insecure_tls" }}
insecure {{ $agg.insecure_tls }}
{{- else if hasKey $agg "ssl_verify" }}
insecure {{ not $agg.ssl_verify }}
{{- else if hasKey $agg "ssl" }}
  {{- if kindIs "map" $agg.ssl }}
    {{- if hasKey $agg.ssl "verify" }}
insecure {{ not $agg.ssl.verify }}
    {{- else if $isHttps }}
insecure false
    {{- else }}
insecure true
    {{- end }}
  {{- else if $isHttps }}
insecure false
  {{- else }}
insecure true
  {{- end }}
{{- else if $isHttps }}
  {{- /* For HTTPS/GRPCS endpoints, default to secure (false) */ -}}
insecure false
{{- else }}
  {{- /* Default for HTTP/GRPC or when not specified: permissive (true) */ -}}
insecure true
{{- end }}
{{- if or $isHttps (hasKey $agg "ca_file") (hasKey $agg "ca_path") (hasKey $agg "cert_file") (hasKey $agg "cert") (hasKey $agg "key_file") (hasKey $agg "key") $sslEnabled (and (hasKey $agg "ssl") (kindIs "map" $agg.ssl) (or (hasKey $agg.ssl "ca_path") (hasKey $agg.ssl "ca_file") (hasKey $agg.ssl "cert_path") (hasKey $agg.ssl "cert_file") (hasKey $agg.ssl "key_path") (hasKey $agg.ssl "key_file"))) }}
  {{- /* CA certificate - support both ca_file and ca_path */ -}}
  {{- if hasKey $agg "ca_file" }}
ca_file {{ $agg.ca_file }}
  {{- else if hasKey $agg "ca_path" }}
ca_path {{ $agg.ca_path }}
  {{- else if hasKey $agg "ssl" }}
    {{- if kindIs "map" $agg.ssl }}
      {{- if hasKey $agg.ssl "ca_path" }}
ca_file {{ $agg.ssl.ca_path }}
      {{- else if hasKey $agg.ssl "ca_file" }}
ca_file {{ $agg.ssl.ca_file }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- /* Client certificate authentication - support both cert_file/cert and key_file/key */ -}}
  {{- if hasKey $agg "cert_file" }}
cert_file {{ $agg.cert_file }}
  {{- else if hasKey $agg "cert" }}
cert_file {{ $agg.cert }}
  {{- else if hasKey $agg "ssl" }}
    {{- if kindIs "map" $agg.ssl }}
      {{- if hasKey $agg.ssl "cert_path" }}
cert_file {{ $agg.ssl.cert_path }}
      {{- else if hasKey $agg.ssl "cert_file" }}
cert_file {{ $agg.ssl.cert_file }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if hasKey $agg "key_file" }}
key_file {{ $agg.key_file }}
  {{- else if hasKey $agg "key" }}
key_file {{ $agg.key }}
  {{- else if hasKey $agg "ssl" }}
    {{- if kindIs "map" $agg.ssl }}
      {{- if hasKey $agg.ssl "key_path" }}
key_file {{ $agg.ssl.key_path }}
      {{- else if hasKey $agg.ssl "key_file" }}
key_file {{ $agg.ssl.key_file }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end -}}

{{- /*
Helper to create final merged labels for Loki
*/ -}}
{{- define "fid.fluentd.lokiMergeLabels" -}}
{{- $logName := .logName -}}
{{- $agg := .aggregator -}}
{{- $final := dict "service_name" (printf "%s.log" $logName) }}
{{- if hasKey $agg "extraLabels" }}
  {{- $userMap := $agg.extraLabels }}
  {{- range $k, $v := $userMap }}
    {{- $_ := set $final $k $v }}
  {{- end }}
{{- end }}
{{ toJson $final }}
{{- end -}}

{{- /*
Helper: Convert aggregator.extraLabels map to actual JSON
*/ -}}
{{- define "fid.fluentd.lokiExtraLabels" -}}
{{- $map := . -}}
{
{{- $keys := list }}
{{- range $k, $v := $map }}
{{- $keys = append $keys $k }}
{{- end }}
{{- $lastIndex := sub (len $keys) 1 }}
{{- range $i, $key := $keys }}
"{{ $key }}":"{{ index $map $key }}"{{ if lt $i $lastIndex }},{{ end }}
{{- end }}
}
{{- end -}}

{{- /*
Source configuration
*/ -}}
{{- define "fid.fluentd.source" -}}
{{- $val := .val -}}
{{- $logName := .logName -}}
{{- $posFileDirectory := .posFileDirectory | default "/opt/radiantone/vds/work/logging" -}}
<source>
  @type tail
  read_from_head true
  path {{ $val.path }}
  pos_file {{ $posFileDirectory | trimSuffix "/" }}/{{ $logName }}.pos
  tag {{ $logName }}
{{- if hasKey $val "parse" }}
  {{- $parseContent := $val.parse | trim }}
  {{- $parseLines := splitList "\n" $parseContent }}
  {{- range $line := $parseLines }}
  {{ $line | trim }}
  {{- end }}
{{- else }}
  format multiline
  format_firstline /\d{4}-\d{1,2}-\d{1,2}/
  format1 /^(?<message>.*)$/
{{- end }}
</source>
{{- end -}}

{{- /*
Filter configuration
*/ -}}
{{- define "fid.fluentd.filter" -}}
{{- $val := .val -}}
{{- $logName := .logName -}}
{{- $clusterName := .clusterName | default "fid-cluster" -}}
<filter {{ $logName }}>
  @type record_transformer
  <record>
    hostname ${hostname}
    clustername {{ $clusterName }}
    log_type {{ $logName }}
  </record>
</filter>
{{- end -}}

{{- /*
Elasticsearch aggregator
Forces => <logName>.log-<clusterName>
*/ -}}
{{- define "fid.fluentd.elasticsearchConfig" -}}
{{- $agg := .aggregator -}}
{{- $logName := .index -}}
{{- $clusterName := .clusterName -}}
{{ include "fid.checkAggregatorKeys" (dict "aggregator" $agg "aggType" "elasticsearch") }}
{{- /* Validate mutually exclusive parameters */ -}}
{{- if and (hasKey $agg "index_name") (hasKey $agg "logstash_format") }}
  {{- if $agg.logstash_format }}
    {{- fail "Cannot use both 'index_name' and 'logstash_format: true' - they are mutually exclusive" }}
  {{- end }}
{{- end }}
<store>
  @type elasticsearch
  {{/* Connection parameters - cloud, hosts, or host+port */}}
  {{- if hasKey $agg "cloud_id" }}
  cloud_id {{ $agg.cloud_id }}
    {{- if hasKey $agg "cloud_auth" }}
  cloud_auth {{ $agg.cloud_auth }}
    {{- end }}
  {{- else if hasKey $agg "hosts" }}
  {{- /* Strip protocol from hosts if mistakenly included */ -}}
  {{- $hosts := $agg.hosts }}
  {{- $hosts = regexReplaceAll "^https?://" $hosts "" }}
  hosts {{ $hosts }}
  {{- else if and (hasKey $agg "host") (hasKey $agg "port") }}
  {{- /* Strip protocol from host if mistakenly included */ -}}
  {{- $host := $agg.host }}
  {{- $host = regexReplaceAll "^https?://" $host "" }}
  host {{ $host }}
  port {{ $agg.port }}
  {{- end }}
  {{- /* Scheme and path - force https when SSL is enabled */ -}}
  {{- $scheme := "http" }}
  {{- $sslEnabled := false }}
  {{- /* Check if SSL is enabled through any method */ -}}
  {{- if and (hasKey $agg "ssl_verify") $agg.ssl_verify }}
    {{- $sslEnabled = true }}
  {{- else if and (hasKey $agg "ssl") (kindIs "map" $agg.ssl) }}
    {{- if and (hasKey $agg.ssl "enabled") $agg.ssl.enabled }}
      {{- $sslEnabled = true }}
    {{- else if and (hasKey $agg.ssl "verify") $agg.ssl.verify }}
      {{- $sslEnabled = true }}
    {{- end }}
  {{- end }}
  {{- /* Determine scheme - SSL always forces https */ -}}
  {{- if $sslEnabled }}
    {{- $scheme = "https" }}
  {{- else if hasKey $agg "scheme" }}
    {{- $scheme = $agg.scheme }}
  {{- end }}
  scheme {{ $scheme }}
  {{- if hasKey $agg "path" }}
  path {{ $agg.path }}
  {{- end }}
  {{- /* Authentication */ -}}
  {{- if hasKey $agg "user" }}
  user {{ $agg.user }}
  {{- end }}
  {{- if hasKey $agg "password" }}
  password {{ $agg.password }}
  {{- end }}
  {{- /* Index configuration - either logstash format OR direct index */ -}}
  {{- if hasKey $agg "index_name" }}
  index_name {{ $agg.index_name }}
  {{- else if hasKey $agg "logstash_format" }}
  logstash_format {{ $agg.logstash_format }}
    {{- if $agg.logstash_format }}
      {{- if hasKey $agg "logstash_prefix" }}
  logstash_prefix {{ $agg.logstash_prefix }}
      {{- else }}
  logstash_prefix {{ printf "%s.log-%s" $logName $clusterName }}
      {{- end }}
      {{- if hasKey $agg "logstash_dateformat" }}
  logstash_dateformat {{ $agg.logstash_dateformat }}
      {{- end }}
      {{- if hasKey $agg "logstash_prefix_separator" }}
  logstash_prefix_separator {{ $agg.logstash_prefix_separator }}
      {{- end }}
    {{- end }}
  {{- else }}
  logstash_format true
  logstash_prefix {{ printf "%s.log-%s" $logName $clusterName }}
  {{- end }}
  {{- /* Dynamic index from record */ -}}
  {{- if hasKey $agg "target_index_key" }}
  target_index_key {{ $agg.target_index_key }}
  {{- end }}
  {{- if hasKey $agg "target_type_key" }}
  target_type_key {{ $agg.target_type_key }}
  {{- end }}
  {{- /* Document configuration */ -}}
  {{- if hasKey $agg "type_name" }}
  type_name {{ $agg.type_name }}
  {{- end }}
  {{- if hasKey $agg "id_key" }}
  id_key {{ $agg.id_key }}
  {{- end }}
  {{- if hasKey $agg "parent_key" }}
  parent_key {{ $agg.parent_key }}
  {{- end }}
  {{- if hasKey $agg "routing_key" }}
  routing_key {{ $agg.routing_key }}
  {{- end }}
  {{- if hasKey $agg "write_operation" }}
  write_operation {{ $agg.write_operation }}
  {{- end }}
  {{- /* Pipeline */ -}}
  {{- if hasKey $agg "pipeline" }}
  pipeline {{ $agg.pipeline }}
  {{- end }}
  {{- /* Template configuration */ -}}
  {{- if hasKey $agg "template_name" }}
  template_name {{ $agg.template_name }}
  {{- end }}
  {{- if hasKey $agg "template_file" }}
  template_file {{ $agg.template_file }}
  {{- end }}
  {{- if hasKey $agg "templates" }}
  templates {{ $agg.templates }}
  {{- end }}
  {{- if hasKey $agg "template_overwrite" }}
  template_overwrite {{ $agg.template_overwrite }}
  {{- end }}
  {{- if hasKey $agg "max_retry_putting_template" }}
  max_retry_putting_template {{ $agg.max_retry_putting_template }}
  {{- end }}
  {{- if hasKey $agg "fail_on_putting_template_retry_exceed" }}
  fail_on_putting_template_retry_exceed {{ $agg.fail_on_putting_template_retry_exceed }}
  {{- end }}
  {{- /* ILM configuration */ -}}
  {{- if hasKey $agg "enable_ilm" }}
  enable_ilm {{ $agg.enable_ilm }}
  {{- end }}
  {{- if hasKey $agg "ilm_policy" }}
  ilm_policy {{ $agg.ilm_policy }}
  {{- end }}
  {{- if hasKey $agg "ilm_policy_id" }}
  ilm_policy_id {{ $agg.ilm_policy_id }}
  {{- end }}
  {{- if hasKey $agg "ilm_policy_overwrite" }}
  ilm_policy_overwrite {{ $agg.ilm_policy_overwrite }}
  {{- end }}
  {{- if hasKey $agg "application_name" }}
  application_name {{ $agg.application_name }}
  {{- end }}
  {{- /* Connection management */ -}}
  {{- if hasKey $agg "reconnect_on_error" }}
  reconnect_on_error {{ $agg.reconnect_on_error }}
  {{- end }}
  {{- if hasKey $agg "reload_connections" }}
  reload_connections {{ $agg.reload_connections }}
  {{- end }}
  {{- if hasKey $agg "reload_on_failure" }}
  reload_on_failure {{ $agg.reload_on_failure }}
  {{- end }}
  {{- if hasKey $agg "resurrect_after" }}
  resurrect_after {{ $agg.resurrect_after }}
  {{- end }}
  {{- if hasKey $agg "request_timeout" }}
  request_timeout {{ $agg.request_timeout }}
  {{- end }}
  {{- if hasKey $agg "max_retry_get_es_version" }}
  max_retry_get_es_version {{ $agg.max_retry_get_es_version }}
  {{- end }}
  {{- /* Time configuration */ -}}
  {{- if hasKey $agg "time_key" }}
  time_key {{ $agg.time_key }}
  {{- end }}
  {{- if hasKey $agg "time_key_format" }}
  time_key_format {{ $agg.time_key_format }}
  {{- end }}
  {{- if hasKey $agg "time_key_exclude_timestamp" }}
  time_key_exclude_timestamp {{ $agg.time_key_exclude_timestamp }}
  {{- end }}
  {{- if hasKey $agg "utc_index" }}
  utc_index {{ $agg.utc_index }}
  {{- end }}
  {{- if hasKey $agg "include_timestamp" }}
  include_timestamp {{ $agg.include_timestamp }}
  {{- else }}
  include_timestamp true
  {{- end }}
  {{- /* Tags and keys */ -}}
  {{- if hasKey $agg "include_tag_key" }}
  include_tag_key {{ $agg.include_tag_key }}
  {{- end }}
  {{- if hasKey $agg "tag_key" }}
  tag_key {{ $agg.tag_key }}
  {{- end }}
  {{- if hasKey $agg "remove_keys" }}
  remove_keys {{ $agg.remove_keys }}
  {{- end }}
  {{- if hasKey $agg "remove_keys_on_update" }}
  remove_keys_on_update {{ $agg.remove_keys_on_update }}
  {{- end }}
  {{- if hasKey $agg "remove_keys_on_update_key" }}
  remove_keys_on_update_key {{ $agg.remove_keys_on_update_key }}
  {{- end }}
  {{- /* Type configuration */ -}}
  {{- if hasKey $agg "suppress_type_name" }}
  suppress_type_name {{ $agg.suppress_type_name }}
  {{- end }}
  {{- /* Serialization */ -}}
  {{- if hasKey $agg "prefer_oj_serializer" }}
  prefer_oj_serializer {{ $agg.prefer_oj_serializer }}
  {{- end }}
  {{- /* Error handling */ -}}
  {{- if hasKey $agg "emit_error_for_missing_id" }}
  emit_error_for_missing_id {{ $agg.emit_error_for_missing_id }}
  {{- end }}
  {{- /* SSL configuration based on scheme or explicit ssl settings */ -}}
  {{- include "fid.fluentd.ssl.elasticsearch" (dict "aggregator" $agg "scheme" $scheme) | nindent 2 }}
  {{- if hasKey $agg "buffer" }}
    {{- include "fid.fluentd.buffer" (dict "config" $agg.buffer "defaultPath" "/var/log/fluentd-buffers/elasticsearch.buffer") | nindent 2 }}
  {{- end }}
</store>
{{- end -}}

{{- /*
OpenSearch aggregator
Forces => <logName>.log-<clusterName>
*/ -}}
{{- define "fid.fluentd.opensearchConfig" -}}
{{- $agg := .aggregator -}}
{{- $logName := .index -}}
{{- $clusterName := .clusterName -}}
{{ include "fid.checkAggregatorKeys" (dict "aggregator" $agg "aggType" "opensearch") }}
{{- /* Validate mutually exclusive parameters */ -}}
{{- if and (hasKey $agg "index_name") (hasKey $agg "logstash_format") }}
  {{- if $agg.logstash_format }}
    {{- fail "Cannot use both 'index_name' and 'logstash_format: true' - they are mutually exclusive" }}
  {{- end }}
{{- end }}
<store>
  @type opensearch
  {{/* Connection parameters */}}
  {{- if hasKey $agg "hosts" }}
  hosts {{ $agg.hosts }}
  {{- else if and (hasKey $agg "host") (hasKey $agg "port") }}
  host {{ $agg.host }}
  port {{ $agg.port }}
  {{- end }}
  {{- /* Scheme and path - force https when SSL is enabled */ -}}
  {{- $scheme := "http" }}
  {{- $sslEnabled := false }}
  {{- /* Check if SSL is enabled through any method */ -}}
  {{- if and (hasKey $agg "ssl_verify") $agg.ssl_verify }}
    {{- $sslEnabled = true }}
  {{- else if and (hasKey $agg "ssl") (kindIs "map" $agg.ssl) }}
    {{- if and (hasKey $agg.ssl "enabled") $agg.ssl.enabled }}
      {{- $sslEnabled = true }}
    {{- else if and (hasKey $agg.ssl "verify") $agg.ssl.verify }}
      {{- $sslEnabled = true }}
    {{- end }}
  {{- end }}
  {{- /* Determine scheme - SSL always forces https */ -}}
  {{- if $sslEnabled }}
    {{- $scheme = "https" }}
  {{- else if hasKey $agg "scheme" }}
    {{- $scheme = $agg.scheme }}
  {{- end }}
  scheme {{ $scheme }}
  {{- if hasKey $agg "path" }}
  path {{ $agg.path }}
  {{- end }}
  {{- /* Authentication */ -}}
  {{- if hasKey $agg "user" }}
  user {{ $agg.user }}
  {{- end }}
  {{- if hasKey $agg "password" }}
  password {{ $agg.password }}
  {{- end }}
  {{- /* Index configuration - either direct index OR logstash format */ -}}
  {{- if hasKey $agg "index_name" }}
  index_name {{ $agg.index_name }}
  {{- else if hasKey $agg "logstash_format" }}
  logstash_format {{ $agg.logstash_format }}
    {{- if $agg.logstash_format }}
      {{- if hasKey $agg "logstash_prefix" }}
  logstash_prefix {{ $agg.logstash_prefix }}
      {{- else }}
  logstash_prefix {{ printf "%s.log-%s" $logName $clusterName }}
      {{- end }}
      {{- if hasKey $agg "logstash_dateformat" }}
  logstash_dateformat {{ $agg.logstash_dateformat }}
      {{- end }}
    {{- end }}
  {{- else }}
  logstash_format true
  logstash_prefix {{ printf "%s.log-%s" $logName $clusterName }}
  {{- end }}
  {{- /* Dynamic index from record */ -}}
  {{- if hasKey $agg "target_index_key" }}
  target_index_key {{ $agg.target_index_key }}
  {{- end }}
  {{- /* Document configuration */ -}}
  {{- if hasKey $agg "type_name" }}
  type_name {{ $agg.type_name }}
  {{- end }}
  {{- if hasKey $agg "id_key" }}
  id_key {{ $agg.id_key }}
  {{- end }}
  {{- if hasKey $agg "parent_key" }}
  parent_key {{ $agg.parent_key }}
  {{- end }}
  {{- if hasKey $agg "routing_key" }}
  routing_key {{ $agg.routing_key }}
  {{- end }}
  {{- if hasKey $agg "write_operation" }}
  write_operation {{ $agg.write_operation }}
  {{- end }}
  {{- /* Pipeline */ -}}
  {{- if hasKey $agg "pipeline" }}
  pipeline {{ $agg.pipeline }}
  {{- end }}
  {{- /* Template configuration */ -}}
  {{- if hasKey $agg "template_name" }}
  template_name {{ $agg.template_name }}
  {{- end }}
  {{- if hasKey $agg "template_file" }}
  template_file {{ $agg.template_file }}
  {{- end }}
  {{- if hasKey $agg "template_overwrite" }}
  template_overwrite {{ $agg.template_overwrite }}
  {{- end }}
  {{- if hasKey $agg "customize_template" }}
  customize_template {{ $agg.customize_template }}
  {{- end }}
  {{- /* Compression */ -}}
  {{- if hasKey $agg "compression_level" }}
  compression_level {{ $agg.compression_level }}
  {{- end }}
  {{- /* Connection management */ -}}
  {{- if hasKey $agg "reconnect_on_error" }}
  reconnect_on_error {{ $agg.reconnect_on_error }}
  {{- end }}
  {{- if hasKey $agg "reload_connections" }}
  reload_connections {{ $agg.reload_connections }}
  {{- end }}
  {{- if hasKey $agg "reload_on_failure" }}
  reload_on_failure {{ $agg.reload_on_failure }}
  {{- end }}
  {{- if hasKey $agg "request_timeout" }}
  request_timeout {{ $agg.request_timeout }}
  {{- end }}
  {{- /* Time configuration */ -}}
  {{- if hasKey $agg "time_key" }}
  time_key {{ $agg.time_key }}
  {{- end }}
  {{- if hasKey $agg "time_key_format" }}
  time_key_format {{ $agg.time_key_format }}
  {{- end }}
  {{- if hasKey $agg "include_timestamp" }}
  include_timestamp {{ $agg.include_timestamp }}
  {{- else }}
  include_timestamp true
  {{- end }}
  {{- /* Tags and keys */ -}}
  {{- if hasKey $agg "include_tag_key" }}
  include_tag_key {{ $agg.include_tag_key }}
  {{- end }}
  {{- if hasKey $agg "tag_key" }}
  tag_key {{ $agg.tag_key }}
  {{- end }}
  {{- if hasKey $agg "remove_keys" }}
  remove_keys {{ $agg.remove_keys }}
  {{- end }}
  {{- /* Document wrapping */ -}}
  {{- if hasKey $agg "suppress_doc_wrap" }}
  suppress_doc_wrap {{ $agg.suppress_doc_wrap }}
  {{- end }}
  {{- if hasKey $agg "suppress_type_name" }}
  suppress_type_name {{ $agg.suppress_type_name }}
  {{- end }}
  {{- /* SSL configuration based on scheme or explicit ssl settings */ -}}
  {{- include "fid.fluentd.ssl.elasticsearch" (dict "aggregator" $agg "scheme" $scheme) | nindent 2 }}
  {{- if hasKey $agg "buffer" }}
    {{- include "fid.fluentd.buffer" (dict "config" $agg.buffer "defaultPath" "/var/log/fluentd-buffers/opensearch.buffer") | nindent 2 }}
  {{- end }}
</store>
{{- end -}}

{{- /*
Splunk aggregator
If aggregator.index => use it
else => bare log name minus ".log"
*/ -}}
{{- define "fid.fluentd.splunkConfig" -}}
{{- $agg := .aggregator -}}
{{- $logName := .index -}}
{{ include "fid.checkAggregatorKeys" (dict "aggregator" $agg "aggType" "splunk_hec") }}
{{- /* Validate mutually exclusive parameters */ -}}
{{- if and (hasKey $agg "index") (hasKey $agg "index_key") }}
  {{- fail "Cannot use both 'index' and 'index_key' - they are mutually exclusive" }}
{{- end }}
{{- if and (hasKey $agg "host") (hasKey $agg "host_key") }}
  {{- fail "Cannot use both 'host' and 'host_key' - they are mutually exclusive" }}
{{- end }}
{{- if and (hasKey $agg "source") (hasKey $agg "source_key") }}
  {{- fail "Cannot use both 'source' and 'source_key' - they are mutually exclusive" }}
{{- end }}
{{- if and (hasKey $agg "sourcetype") (hasKey $agg "sourcetype_key") }}
  {{- fail "Cannot use both 'sourcetype' and 'sourcetype_key' - they are mutually exclusive" }}
{{- end }}
{{- /* Validate required channel when using ACK */ -}}
{{- if and (hasKey $agg "use_ack") $agg.use_ack }}
  {{- if not (hasKey $agg "channel") }}
    {{- fail "Splunk HEC requires 'channel' parameter when 'use_ack: true'" }}
  {{- end }}
{{- end }}
<store>
  @type splunk_hec
  {{/* Connection parameters */}}
  hec_host {{ $agg.hec_host }}
  hec_port {{ $agg.hec_port }}
  hec_token {{ $agg.hec_token }}
  {{- if hasKey $agg "protocol" }}
  protocol {{ $agg.protocol }}
  {{- end }}
  {{- /* Index - either static or dynamic from record */ -}}
  {{- if hasKey $agg "index_key" }}
  index_key {{ $agg.index_key }}
  {{- else if hasKey $agg "index" }}
  index {{ $agg.index }}
  {{- else }}
  index {{ include "fid.fluentd.stripDotLog" $logName }}
  {{- end }}
  {{- /* Host - either static or dynamic from record */ -}}
  {{- if hasKey $agg "host_key" }}
  host_key {{ $agg.host_key }}
  {{- else if hasKey $agg "host" }}
  host {{ $agg.host }}
  {{- end }}
  {{- /* Source - either static or dynamic from record */ -}}
  {{- if hasKey $agg "source_key" }}
  source_key {{ $agg.source_key }}
  {{- else if hasKey $agg "source" }}
  source {{ $agg.source }}
  {{- end }}
  {{- /* Sourcetype - either static or dynamic from record */ -}}
  {{- if hasKey $agg "sourcetype_key" }}
  sourcetype_key {{ $agg.sourcetype_key }}
  {{- else if hasKey $agg "sourcetype" }}
  sourcetype {{ $agg.sourcetype }}
  {{- end }}
  {{- /* Data type configuration */ -}}
  {{- if hasKey $agg "data_type" }}
  data_type {{ $agg.data_type }}
  {{- end }}
  {{- /* Metrics configuration */ -}}
  {{- if hasKey $agg "metrics_from_event" }}
  metrics_from_event {{ $agg.metrics_from_event }}
  {{- end }}
  {{- if hasKey $agg "metric_name_key" }}
  metric_name_key {{ $agg.metric_name_key }}
  {{- end }}
  {{- if hasKey $agg "metric_value_key" }}
  metric_value_key {{ $agg.metric_value_key }}
  {{- end }}
  {{- /* ACK configuration */ -}}
  {{- if hasKey $agg "use_ack" }}
  use_ack {{ $agg.use_ack }}
  {{- end }}
  {{- if hasKey $agg "channel" }}
  channel {{ $agg.channel }}
  {{- end }}
  {{- if hasKey $agg "ack_retry" }}
  ack_retry {{ $agg.ack_retry }}
  {{- end }}
  {{- if hasKey $agg "ack_retry_limit" }}
  ack_retry_limit {{ $agg.ack_retry_limit }}
  {{- end }}
  {{- /* Time configuration */ -}}
  {{- if hasKey $agg "use_fluentd_time" }}
  use_fluentd_time {{ $agg.use_fluentd_time }}
  {{- end }}
  {{- if hasKey $agg "time_as_integer" }}
  time_as_integer {{ $agg.time_as_integer }}
  {{- end }}
  {{- /* Fields - custom dimensions */ -}}
  {{- if hasKey $agg "fields" }}
  <fields>
    {{- range $key, $value := $agg.fields }}
    {{ $key }} {{ $value }}
    {{- end }}
  </fields>
  {{- end }}
  {{- /* Connection settings */ -}}
  {{- if hasKey $agg "idle_timeout" }}
  idle_timeout {{ $agg.idle_timeout }}
  {{- end }}
  {{- if hasKey $agg "read_timeout" }}
  read_timeout {{ $agg.read_timeout }}
  {{- end }}
  {{- /* Raw mode */ -}}
  {{- if hasKey $agg "raw" }}
  raw {{ $agg.raw }}
  {{- end }}
  {{- /* Key management */ -}}
  {{- if hasKey $agg "keep_keys" }}
  keep_keys {{ $agg.keep_keys }}
  {{- end }}
  {{- /* UTF-8 handling */ -}}
  {{- if hasKey $agg "coerce_to_utf8" }}
  coerce_to_utf8 {{ $agg.coerce_to_utf8 }}
  {{- end }}
  {{- if hasKey $agg "non_utf8_replacement_string" }}
  non_utf8_replacement_string {{ $agg.non_utf8_replacement_string }}
  {{- end }}
  {{- /* SSL configuration for Splunk */ -}}
  {{- include "fid.fluentd.ssl.splunk" $agg | nindent 2 }}
  {{- /* Additional SSL parameters */ -}}
  {{- if hasKey $agg "ssl_ciphers" }}
  ssl_ciphers {{ $agg.ssl_ciphers }}
  {{- end }}
  {{- if hasKey $agg "buffer" }}
    {{- include "fid.fluentd.buffer" (dict "config" $agg.buffer "defaultPath" "/var/log/fluentd-buffers/splunk.buffer") | nindent 2 }}
  {{- end }}
</store>
{{- end -}}

{{- /*
Loki aggregator
Merges default label service_name => "<logName>.log" with aggregator.extraLabels
*/ -}}
{{- define "fid.fluentd.lokiConfig" -}}
{{- $globalCtx := .context -}}
{{- $agg := .aggregator -}}
{{- $logName := .index -}}
{{ include "fid.checkAggregatorKeys" (dict "aggregator" $agg "aggType" "loki") }}
<store>
  @type loki
  {{/* Connection */}}
  url {{ $agg.url }}
  {{/* Authentication - multiple options */}}
  {{- if hasKey $agg "username" }}
  username {{ $agg.username }}
  {{- end }}
  {{- if hasKey $agg "password" }}
  password {{ $agg.password }}
  {{- end }}
  {{- if hasKey $agg "tenant" }}
  tenant {{ $agg.tenant }}
  {{- end }}
  {{- if hasKey $agg "bearer_token_file" }}
  bearer_token_file {{ $agg.bearer_token_file }}
  {{- end }}
  {{- /* Labels configuration with automatic defaults */ -}}
  {{- $defaultLabels := dict }}
  {{- /* Generate automatic labels for Loki dashboards */ -}}
  {{- $_ := set $defaultLabels "service_name" (coalesce $globalCtx.Values.alternateName $globalCtx.Values.nameOverride $globalCtx.Chart.Name | trunc 63 | trimSuffix "-") }}
  {{- $_ := set $defaultLabels "file" (printf "%s.log" $logName) }}
  {{- $_ := set $defaultLabels "environment" (include "tenant.name" $globalCtx) }}
  {{- $_ := set $defaultLabels "tenant" (include "tenant.name" $globalCtx) }}
  {{- $_ := set $defaultLabels "app" "#{ENV['LABEL_APP']}" }}
  {{- $_ := set $defaultLabels "instance" $globalCtx.Release.Name }}
  {{- $_ := set $defaultLabels "component" "fid" }}
  {{- $_ := set $defaultLabels "job" (printf "%s/%s" "#{ENV['POD_NAMESPACE']}" "#{ENV['LABEL_APP']}") }}
  {{- $_ := set $defaultLabels "pod" "#{ENV['POD_NAME']}" }}
  {{- $_ := set $defaultLabels "node_name" "#{ENV['NODE_NAME']}" }}
  {{- $_ := set $defaultLabels "namespace" "#{ENV['POD_NAMESPACE']}" }}
  {{- /* Get user-provided labels (create a copy to avoid mutation) */ -}}
  {{- $userLabels := dict }}
  {{- if hasKey $agg "extra_labels" -}}
    {{- $userLabels = deepCopy $agg.extra_labels }}
  {{- else if hasKey $agg "extraLabels" -}}
    {{- $userLabels = deepCopy $agg.extraLabels }}
  {{- end }}
  {{- /* Merge labels: user labels override defaults */ -}}
  {{- $finalLabels := merge $userLabels $defaultLabels }}
  {{- if $finalLabels }}
  extra_labels {{ $finalLabels | toJson }}
  {{- end }}
  {{- if hasKey $agg "include_thread_label" }}
  include_thread_label {{ $agg.include_thread_label }}
  {{- end }}
  {{- /* Kubernetes integration */ -}}
  {{- if hasKey $agg "extract_kubernetes_labels" }}
  extract_kubernetes_labels {{ $agg.extract_kubernetes_labels }}
  {{- end }}
  {{- /* Format configuration */ -}}
  {{- if hasKey $agg "drop_single_key" }}
  drop_single_key {{ $agg.drop_single_key }}
  {{- end }}
  {{- if hasKey $agg "remove_keys" }}
  remove_keys {{ $agg.remove_keys }}
  {{- end }}
  {{- if hasKey $agg "line_format" }}
  line_format {{ $agg.line_format }}
  {{- end }}
  {{- /* SSL configuration for Loki */ -}}
  {{- include "fid.fluentd.ssl.loki" $agg | nindent 2 }}
  {{- /* Alternative cert/key names (some versions use these) */ -}}
  {{- if hasKey $agg "cert" }}
  cert {{ $agg.cert }}
  {{- end }}
  {{- if hasKey $agg "key" }}
  key {{ $agg.key }}
  {{- end }}
  {{- /* TLS configuration extensions */ -}}
  {{- if hasKey $agg "ciphers" }}
  ciphers {{ $agg.ciphers }}
  {{- end }}
  {{- if hasKey $agg "min_version" }}
  min_version {{ $agg.min_version }}
  {{- end }}
  {{- /* Compression */ -}}
  {{- if hasKey $agg "compress" }}
  compress {{ $agg.compress }}
  {{- end }}
  {{- /* Custom HTTP headers */ -}}
  {{- if hasKey $agg "custom_headers" }}
    {{- range $key, $value := $agg.custom_headers }}
  <headers>
    {{ $key }} {{ $value }}
  </headers>
    {{- end }}
  {{- end }}
  {{- if hasKey $agg "buffer" }}
    {{- include "fid.fluentd.buffer" (dict "config" $agg.buffer "defaultPath" "/var/log/fluentd-buffers/loki.buffer") | nindent 2 }}
  {{- end }}
</store>
{{- end -}}

{{- /*
Sumologic aggregator
*/ -}}
{{- define "fid.fluentd.sumologicConfig" -}}
{{- $agg := .aggregator -}}
{{- $index := .index -}}
{{ include "fid.checkAggregatorKeys" (dict "aggregator" $agg "aggType" "sumologic") }}
{{- /* Validate mutually exclusive parameters */ -}}
{{- if and (hasKey $agg "source_name") (hasKey $agg "source_name_key") }}
  {{- fail "Cannot use both 'source_name' and 'source_name_key' - they are mutually exclusive" }}
{{- end }}
{{- if and (hasKey $agg "source_host") (hasKey $agg "source_host_key") }}
  {{- fail "Cannot use both 'source_host' and 'source_host_key' - they are mutually exclusive" }}
{{- end }}
{{- if and (hasKey $agg "source_category") (hasKey $agg "source_category_key") }}
  {{- fail "Cannot use both 'source_category' and 'source_category_key' - they are mutually exclusive" }}
{{- end }}
<store>
  @type sumologic
  endpoint {{ $agg.endpoint }}
  {{/* Source configuration - either static or dynamic from record */}}
  {{- if hasKey $agg "source_name_key" }}
  source_name_key {{ $agg.source_name_key }}
  {{- else if hasKey $agg "source_name" }}
  source_name {{ $agg.source_name }}
  {{- end }}
  {{- if hasKey $agg "source_host_key" }}
  source_host_key {{ $agg.source_host_key }}
  {{- else if hasKey $agg "source_host" }}
  source_host {{ $agg.source_host }}
  {{- end }}
  {{- if hasKey $agg "source_category_key" }}
  source_category_key {{ $agg.source_category_key }}
  {{- else if hasKey $agg "source_category" }}
  source_category {{ $agg.source_category }}
  {{- end }}
  {{- if hasKey $agg "source_category_prefix" }}
  source_category_prefix {{ $agg.source_category_prefix }}
  {{- end }}
  {{- if hasKey $agg "source_category_replace_dash" }}
  source_category_replace_dash {{ $agg.source_category_replace_dash }}
  {{- end }}
  {{- /* Data type configuration */ -}}
  {{- if hasKey $agg "data_type" }}
  data_type {{ $agg.data_type }}
  {{- end }}
  {{- /* Metrics format - support both official name and variations */ -}}
  {{- if hasKey $agg "metric_data_format" }}
  metric_data_format {{ $agg.metric_data_format }}
  {{- else if hasKey $agg "metric_data_type" }}
  metric_data_format {{ $agg.metric_data_type }}
  {{- else if hasKey $agg "metrics_data_type" }}
  metric_data_format {{ $agg.metrics_data_type }}
  {{- end }}
  {{- /* Log format configuration */ -}}
  {{- if hasKey $agg "log_format" }}
  log_format {{ $agg.log_format }}
  {{- end }}
  {{- if hasKey $agg "json_merge" }}
  json_merge {{ $agg.json_merge }}
  {{- end }}
  {{- if hasKey $agg "log_key" }}
  log_key {{ $agg.log_key }}
  {{- end }}
  {{- /* Timestamp configuration */ -}}
  {{- if hasKey $agg "add_timestamp" }}
  add_timestamp {{ $agg.add_timestamp }}
  {{- end }}
  {{- if hasKey $agg "add_timestamp_key" }}
  add_timestamp_key {{ $agg.add_timestamp_key }}
  {{- end }}
  {{- if hasKey $agg "timestamp_key" }}
  timestamp_key {{ $agg.timestamp_key }}
  {{- end }}
  {{- /* Compression */ -}}
  {{- if hasKey $agg "compress" }}
  compress {{ $agg.compress }}
  {{- end }}
  {{- if hasKey $agg "compress_encoding" }}
  compress_encoding {{ $agg.compress_encoding }}
  {{- end }}
  {{- /* Proxy configuration */ -}}
  {{- if hasKey $agg "proxy_uri" }}
  proxy_uri {{ $agg.proxy_uri }}
  {{- end }}
  {{- if hasKey $agg "proxy_cert" }}
  proxy_cert {{ $agg.proxy_cert }}
  {{- end }}
  {{- if hasKey $agg "proxy_key" }}
  proxy_key {{ $agg.proxy_key }}
  {{- end }}
  {{- /* Connection settings */ -}}
  {{- if hasKey $agg "open_timeout" }}
  open_timeout {{ $agg.open_timeout }}
  {{- end }}
  {{- if hasKey $agg "send_timeout" }}
  send_timeout {{ $agg.send_timeout }}
  {{- end }}
  {{- if hasKey $agg "receive_timeout" }}
  receive_timeout {{ $agg.receive_timeout }}
  {{- end }}
  {{- if hasKey $agg "disable_cookies" }}
  disable_cookies {{ $agg.disable_cookies }}
  {{- end }}
  {{- /* Additional metadata fields */ -}}
  {{- if hasKey $agg "delimiter" }}
  delimiter {{ $agg.delimiter }}
  {{- end }}
  {{- if hasKey $agg "custom_fields" }}
  custom_fields {{ $agg.custom_fields }}
  {{- end }}
  {{- if hasKey $agg "custom_dimensions" }}
  custom_dimensions {{ $agg.custom_dimensions }}
  {{- end }}
  {{- if hasKey $agg "sumo_client" }}
  sumo_client {{ $agg.sumo_client }}
  {{- end }}
  {{- /* Retry configuration */ -}}
  {{- if hasKey $agg "use_internal_retry" }}
  use_internal_retry {{ $agg.use_internal_retry }}
  {{- end }}
  {{- if hasKey $agg "retry_timeout" }}
  retry_timeout {{ $agg.retry_timeout }}
  {{- end }}
  {{- if hasKey $agg "retry_max_times" }}
  retry_max_times {{ $agg.retry_max_times }}
  {{- end }}
  {{- if hasKey $agg "retry_min_interval" }}
  retry_min_interval {{ $agg.retry_min_interval }}
  {{- end }}
  {{- if hasKey $agg "retry_max_interval" }}
  retry_max_interval {{ $agg.retry_max_interval }}
  {{- end }}
  {{- /* Request size limit */ -}}
  {{- if hasKey $agg "max_request_size" }}
  max_request_size {{ $agg.max_request_size }}
  {{- end }}
  {{- /* SSL configuration for Sumologic */ -}}
  {{- include "fid.fluentd.ssl.sumologic" $agg | nindent 2 }}
  {{- if hasKey $agg "buffer" }}
    {{- include "fid.fluentd.buffer" (dict "config" $agg.buffer "defaultPath" "/var/log/fluentd-buffers/sumologic.buffer") | nindent 2 }}
  {{- end }}
</store>
{{- end -}}

{{- /*
S3 aggregator
*/ -}}
{{- define "fid.fluentd.s3Config" -}}
{{- $agg := .aggregator -}}
{{- $index := .index -}}
{{ include "fid.checkAggregatorKeys" (dict "aggregator" $agg "aggType" "s3") }}
<store>
  @type s3
  {{- /* Support both old and new parameter names */ -}}
  {{- $bucket := $agg.s3_bucket | default $agg.bucket }}
  {{- $region := $agg.s3_region | default $agg.region }}
  {{- if not $bucket }}
    {{- fail "S3 aggregator requires 's3_bucket' or 'bucket' parameter" }}
  {{- end }}
  {{- if not $region }}
    {{- fail "S3 aggregator requires 's3_region' or 'region' parameter" }}
  {{- end }}
  s3_bucket {{ $bucket }}
  s3_region {{ $region }}
  {{- /* S3 endpoint for S3-compatible storage */ -}}
  {{- if hasKey $agg "s3_endpoint" }}
  s3_endpoint {{ $agg.s3_endpoint }}
  {{- end }}
  {{- /* AWS authentication */ -}}
  {{- if hasKey $agg "aws_key_id" }}
  aws_key_id {{ $agg.aws_key_id }}
  {{- end }}
  {{- if hasKey $agg "aws_sec_key" }}
  aws_sec_key {{ $agg.aws_sec_key }}
  {{- end }}
  {{- /* IAM role assumption */ -}}
  {{- if hasKey $agg "assume_role_credentials" }}
  assume_role_credentials {{ $agg.assume_role_credentials }}
  {{- end }}
  {{- if hasKey $agg "role_arn" }}
  role_arn {{ $agg.role_arn }}
  {{- end }}
  {{- if hasKey $agg "role_session_name" }}
  role_session_name {{ $agg.role_session_name }}
  {{- end }}
  {{- if hasKey $agg "external_id" }}
  external_id {{ $agg.external_id }}
  {{- end }}
  {{- /* Path and object key configuration */ -}}
  path {{ $agg.path | default "logs/%Y/%m/%d/" }}
  {{- if hasKey $agg "s3_object_key_format" }}
  s3_object_key_format {{ $agg.s3_object_key_format }}
  {{- else }}
  s3_object_key_format %{path}%{time_slice}_%{index}.%{file_extension}
  {{- end }}
  {{- /* Storage configuration */ -}}
  store_as {{ $agg.store_as | default "gzip" }}
  {{- if hasKey $agg "storage_class" }}
  storage_class {{ $agg.storage_class }}
  {{- end }}
  {{- /* Format configuration */ -}}
  {{- if hasKey $agg "format" }}
  <format>
    @type {{ $agg.format | default "json" }}
    {{- if hasKey $agg "format_json_flatten" }}
    flatten {{ $agg.format_json_flatten }}
    {{- end }}
  </format>
  {{- else }}
  <format>
    @type json
  </format>
  {{- end }}
  {{- if hasKey $agg "compression" }}
  compression {{ $agg.compression }}
  {{- end }}
  {{- /* SSL configuration */ -}}
  {{- if hasKey $agg "use_ssl" }}
  use_ssl {{ $agg.use_ssl }}
  {{- end }}
  {{- if hasKey $agg "ssl_verify_peer" }}
  ssl_verify_peer {{ $agg.ssl_verify_peer }}
  {{- end }}
  {{- if hasKey $agg "force_path_style" }}
  force_path_style {{ $agg.force_path_style }}
  {{- end }}
  {{- /* Server-side encryption */ -}}
  {{- if hasKey $agg "use_server_side_encryption" }}
  use_server_side_encryption {{ $agg.use_server_side_encryption }}
  {{- end }}
  {{- if hasKey $agg "ssekms_key_id" }}
  ssekms_key_id {{ $agg.ssekms_key_id }}
  {{- end }}
  {{- if hasKey $agg "sse_customer_algorithm" }}
  sse_customer_algorithm {{ $agg.sse_customer_algorithm }}
  {{- end }}
  {{- if hasKey $agg "sse_customer_key" }}
  sse_customer_key {{ $agg.sse_customer_key }}
  {{- end }}
  {{- if hasKey $agg "sse_customer_key_md5" }}
  sse_customer_key_md5 {{ $agg.sse_customer_key_md5 }}
  {{- end }}
  {{- /* Access control */ -}}
  {{- if hasKey $agg "acl" }}
  acl {{ $agg.acl }}
  {{- end }}
  {{- if hasKey $agg "grant_full_control" }}
  grant_full_control {{ $agg.grant_full_control }}
  {{- end }}
  {{- if hasKey $agg "grant_read" }}
  grant_read {{ $agg.grant_read }}
  {{- end }}
  {{- if hasKey $agg "grant_read_acp" }}
  grant_read_acp {{ $agg.grant_read_acp }}
  {{- end }}
  {{- if hasKey $agg "grant_write_acp" }}
  grant_write_acp {{ $agg.grant_write_acp }}
  {{- end }}
  {{- /* Bucket management */ -}}
  {{- if hasKey $agg "auto_create_bucket" }}
  auto_create_bucket {{ $agg.auto_create_bucket }}
  {{- end }}
  {{- if hasKey $agg "overwrite" }}
  overwrite {{ $agg.overwrite }}
  {{- end }}
  {{- if hasKey $agg "check_object" }}
  check_object {{ $agg.check_object }}
  {{- end }}
  {{- if hasKey $agg "check_bucket" }}
  check_bucket {{ $agg.check_bucket }}
  {{- end }}
  {{- /* Time configuration */ -}}
  {{- if hasKey $agg "time_slice_format" }}
  time_slice_format {{ $agg.time_slice_format }}
  {{- end }}
  {{- if hasKey $agg "utc" }}
  utc {{ $agg.utc }}
  {{- end }}
  {{- if hasKey $agg "hex_random_length" }}
  hex_random_length {{ $agg.hex_random_length }}
  {{- end }}
  {{- if hasKey $agg "index_format" }}
  index_format {{ $agg.index_format }}
  {{- end }}
  {{- /* Monitoring */ -}}
  {{- if hasKey $agg "warn_for_delay" }}
  warn_for_delay {{ $agg.warn_for_delay }}
  {{- end }}
  {{- if hasKey $agg "buffer" }}
    {{- include "fid.fluentd.buffer" (dict "config" $agg.buffer "defaultPath" "/var/log/fluentd-buffers/s3.buffer") | nindent 2 }}
  {{- end }}
</store>
{{- end -}}

{{- /*
Azure Event Hubs aggregator
Uses fluent-plugin-azureeventhubs-radiant

Sends logs to Azure Event Hubs using HTTPS protocol.
Supports batching, proxy configuration, and custom message properties.

Required parameters:
  - connection_string: Azure Event Hub connection string (with SharedAccessKey)
  - hub_name: Name of the Event Hub within the namespace

Optional parameters:
  - include_tag: Add Fluentd tag to each record (default: false)
  - include_time: Add timestamp to each record (default: false)
  - tag_time_name: Field name for timestamp when include_time is true (default: "time")
  - expiry_interval: SAS token expiry in seconds (default: 3600)
  - batch: Enable batch mode for better throughput (default: false)
  - max_batch_size: Max records per batch when batch=true (default: 20)
  - proxy_addr: HTTP proxy address for corporate networks
  - proxy_port: HTTP proxy port (default: 3128)
  - open_timeout: Connection timeout in seconds (default: 60)
  - read_timeout: Read timeout in seconds (default: 60)
  - ssl_verify: Verify SSL certificates (default: true)
  - coerce_to_utf8: Convert records to UTF-8 (default: true)
  - non_utf8_replacement_string: Replacement for non-UTF8 chars (default: " ")
  - print_records: Debug mode - log records to fluentd log (default: false)
  - message_properties: Custom properties to add to each message (hash)
  - buffer: Buffer configuration block
*/ -}}
{{- define "fid.fluentd.azureEventHubsConfig" -}}
{{- $agg := .aggregator -}}
{{- $index := .index -}}
{{ include "fid.checkAggregatorKeys" (dict "aggregator" $agg "aggType" "azure_event_hubs") }}
<store>
  @type azureeventhubs
  {{/* Required connection parameters */}}
  connection_string {{ $agg.connection_string }}
  hub_name {{ $agg.hub_name }}
  {{- /* Record enrichment options */ -}}
  {{- if hasKey $agg "include_tag" }}
  include_tag {{ $agg.include_tag }}
  {{- end }}
  {{- if hasKey $agg "include_time" }}
  include_time {{ $agg.include_time }}
  {{- end }}
  {{- if hasKey $agg "tag_time_name" }}
  tag_time_name {{ $agg.tag_time_name }}
  {{- end }}
  {{- /* Authentication and security */ -}}
  {{- if hasKey $agg "expiry_interval" }}
  expiry_interval {{ $agg.expiry_interval }}
  {{- end }}
  {{- if hasKey $agg "ssl_verify" }}
  ssl_verify {{ $agg.ssl_verify }}
  {{- end }}
  {{- /* Batching configuration for throughput optimization */ -}}
  {{- if hasKey $agg "batch" }}
  batch {{ $agg.batch }}
  {{- end }}
  {{- if hasKey $agg "max_batch_size" }}
  max_batch_size {{ $agg.max_batch_size }}
  {{- end }}
  {{- /* Proxy configuration for corporate networks */ -}}
  {{- if hasKey $agg "proxy_addr" }}
  proxy_addr {{ $agg.proxy_addr }}
  {{- end }}
  {{- if hasKey $agg "proxy_port" }}
  proxy_port {{ $agg.proxy_port }}
  {{- end }}
  {{- /* Timeout settings */ -}}
  {{- if hasKey $agg "open_timeout" }}
  open_timeout {{ $agg.open_timeout }}
  {{- end }}
  {{- if hasKey $agg "read_timeout" }}
  read_timeout {{ $agg.read_timeout }}
  {{- end }}
  {{- /* Character encoding */ -}}
  {{- if hasKey $agg "coerce_to_utf8" }}
  coerce_to_utf8 {{ $agg.coerce_to_utf8 }}
  {{- end }}
  {{- if hasKey $agg "non_utf8_replacement_string" }}
  non_utf8_replacement_string {{ $agg.non_utf8_replacement_string }}
  {{- end }}
  {{- /* Debugging */ -}}
  {{- if hasKey $agg "print_records" }}
  print_records {{ $agg.print_records }}
  {{- end }}
  {{- /* Custom message properties - adds metadata to each Event Hub message */ -}}
  {{- /* message_properties is a :hash type in the plugin, so it needs JSON format */ -}}
  {{- if hasKey $agg "message_properties" }}
  message_properties {{ $agg.message_properties | toJson }}
  {{- end }}
  {{- /* Buffer configuration */ -}}
  {{- if hasKey $agg "buffer" }}
    {{- include "fid.fluentd.buffer" (dict "config" $agg.buffer "defaultPath" "/var/log/fluentd-buffers/azure-eventhubs.buffer") | nindent 2 }}
  {{- end }}
</store>
{{- end -}}

{{- /*
OpenTelemetry aggregator
Sends logs to OpenTelemetry Collector via OTLP (OpenTelemetry Protocol)
Supports both gRPC and HTTP protocols
*/ -}}
{{- define "fid.fluentd.opentelemetryConfig" -}}
{{- $globalCtx := .context -}}
{{- $agg := .aggregator -}}
{{- $logName := .index -}}
{{ include "fid.checkAggregatorKeys" (dict "aggregator" $agg "aggType" "opentelemetry") }}
{{- /* Validate mutually exclusive parameters */ -}}
{{- if and (hasKey $agg "service_name") (hasKey $agg "service_name_key") }}
  {{- fail "Cannot use both 'service_name' and 'service_name_key' - they are mutually exclusive" }}
{{- end }}
{{- if and (hasKey $agg "resource_attributes") (hasKey $agg "resource_attributes_key") }}
  {{- fail "Cannot use both 'resource_attributes' and 'resource_attributes_key' - they are mutually exclusive" }}
{{- end }}
{{- if and (hasKey $agg "headers") (hasKey $agg "headers_key") }}
  {{- fail "Cannot use both 'headers' and 'headers_key' - they are mutually exclusive" }}
{{- end }}
{{- /* Validate endpoint or host+port */ -}}
{{- if not (or (hasKey $agg "endpoint") (and (hasKey $agg "host") (hasKey $agg "port"))) }}
  {{- fail "OpenTelemetry aggregator requires either 'endpoint' OR both 'host' and 'port'" }}
{{- end }}
<store>
  @type opentelemetry
  {{/* Connection - support both endpoint URL and host+port */}}
  {{- if hasKey $agg "endpoint" }}
  endpoint {{ $agg.endpoint }}
  {{- else if and (hasKey $agg "host") (hasKey $agg "port") }}
  host {{ $agg.host }}
  port {{ $agg.port }}
  {{- end }}
  {{- /* Protocol - gRPC or HTTP */ -}}
  {{- if hasKey $agg "protocol" }}
  protocol {{ $agg.protocol }}
  {{- else }}
  protocol grpc
  {{- end }}
  {{- /* Service name configuration */ -}}
  {{- if hasKey $agg "service_name_key" }}
  service_name_key {{ $agg.service_name_key }}
  {{- else if hasKey $agg "service_name" }}
  service_name {{ $agg.service_name }}
  {{- else }}
  service_name {{ coalesce $globalCtx.Values.alternateName $globalCtx.Values.nameOverride $globalCtx.Chart.Name | trunc 63 | trimSuffix "-" }}
  {{- end }}
  {{- /* Resource attributes - OpenTelemetry resource metadata */ -}}
  {{- if hasKey $agg "resource_attributes_key" }}
  resource_attributes_key {{ $agg.resource_attributes_key }}
  {{- else if hasKey $agg "resource_attributes" }}
  resource_attributes {{ $agg.resource_attributes | toJson }}
  {{- end }}
  {{- /* Headers - custom HTTP/gRPC headers */ -}}
  {{- if hasKey $agg "headers_key" }}
  headers_key {{ $agg.headers_key }}
  {{- else if hasKey $agg "headers" }}
  headers {{ $agg.headers | toJson }}
  {{- end }}
  {{- /* Timeout settings */ -}}
  {{- if hasKey $agg "timeout" }}
  timeout {{ $agg.timeout }}
  {{- end }}
  {{- if hasKey $agg "open_timeout" }}
  open_timeout {{ $agg.open_timeout }}
  {{- end }}
  {{- if hasKey $agg "read_timeout" }}
  read_timeout {{ $agg.read_timeout }}
  {{- end }}
  {{- /* Compression */ -}}
  {{- if hasKey $agg "compression" }}
  compression {{ $agg.compression }}
  {{- end }}
  {{- if hasKey $agg "compression_level" }}
  compression_level {{ $agg.compression_level }}
  {{- end }}
  {{- /* Format configuration */ -}}
  {{- if hasKey $agg "format" }}
  format {{ $agg.format }}
  {{- end }}
  {{- if hasKey $agg "json_array" }}
  json_array {{ $agg.json_array }}
  {{- end }}
  {{- /* Tag and key management */ -}}
  {{- if hasKey $agg "include_tag_key" }}
  include_tag_key {{ $agg.include_tag_key }}
  {{- end }}
  {{- if hasKey $agg "tag_key" }}
  tag_key {{ $agg.tag_key }}
  {{- end }}
  {{- if hasKey $agg "remove_keys" }}
  remove_keys {{ $agg.remove_keys }}
  {{- end }}
  {{- /* Timestamp configuration */ -}}
  {{- if hasKey $agg "add_timestamp" }}
  add_timestamp {{ $agg.add_timestamp }}
  {{- end }}
  {{- if hasKey $agg "timestamp_key" }}
  timestamp_key {{ $agg.timestamp_key }}
  {{- end }}
  {{- /* SSL/TLS configuration */ -}}
  {{- include "fid.fluentd.ssl.opentelemetry" $agg | nindent 2 }}
  {{- if hasKey $agg "buffer" }}
    {{- include "fid.fluentd.buffer" (dict "config" $agg.buffer "defaultPath" "/var/log/fluentd-buffers/opentelemetry.buffer") | nindent 2 }}
  {{- end }}
</store>
{{- end -}}

{{- /*
Main aggregator configuration
*/ -}}
{{- define "fid.fluentd.aggregator" -}}
{{- $globalCtx := .context -}}
{{- $aggregator := .aggregator -}}
{{- $index := .index -}}
{{- $clusterName := .clusterName -}}
{{- $aggType := $aggregator.type -}}
{{- if not $aggType }}
{{- fail "Aggregator type is required." -}}
{{- end }}
  {{- if eq $aggType "elasticsearch" }}
    {{- include "fid.fluentd.elasticsearchConfig" (dict "aggregator" $aggregator "index" $index "clusterName" $clusterName) }}
  {{- else if eq $aggType "opensearch" }}
    {{- include "fid.fluentd.opensearchConfig" (dict "aggregator" $aggregator "index" $index "clusterName" $clusterName) }}
  {{- else if eq $aggType "splunk_hec" }}
    {{- include "fid.fluentd.splunkConfig" (dict "aggregator" $aggregator "index" $index) }}
  {{- else if eq $aggType "loki" }}
    {{- include "fid.fluentd.lokiConfig" (dict "aggregator" $aggregator "index" $index "context" $globalCtx) }}
  {{- else if eq $aggType "sumologic" }}
    {{- include "fid.fluentd.sumologicConfig" (dict "aggregator" $aggregator "index" $index) }}
  {{- else if eq $aggType "s3" }}
    {{- include "fid.fluentd.s3Config" (dict "aggregator" $aggregator "index" $index) }}
  {{- else if eq $aggType "azure_event_hubs" }}
    {{- include "fid.fluentd.azureEventHubsConfig" (dict "aggregator" $aggregator "index" $index) }}
  {{- else if eq $aggType "opentelemetry" }}
    {{- include "fid.fluentd.opentelemetryConfig" (dict "aggregator" $aggregator "index" $index "context" $globalCtx) }}
  {{- else }}
    {{- fail (printf "Unsupported aggregator type: %s" $aggType) }}
  {{- end }}
{{- end -}}

{{- /*
Main match configuration
*/ -}}
{{- define "fid.fluentd.match" -}}
{{- $globalCtx := .context -}}
{{- $val := .val -}}
{{- $logName := .logName -}}
{{- $aggregatorsList := .aggregatorsList -}}
{{- $clusterName := .clusterName | default "fid-cluster" -}}
<match {{ $logName }}>
  @type copy
{{- range $aggName := $val.aggregators }}
  {{- $foundAgg := false }}
  {{- range $key, $aggs := $aggregatorsList }}
    {{- if eq (toString $key | lower) (toString $aggName | lower) }}
      {{- $foundAgg = true }}
      {{- range $aggregator := $aggs }}
        {{- include "fid.fluentd.aggregator" (dict "aggregator" $aggregator "index" $logName "clusterName" $clusterName "context" $globalCtx) | nindent 2 }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if not $foundAgg }}
    {{- fail (printf "Aggregator '%s' not found in values." $aggName) }}
  {{- end }}
{{- end }}
</match>
{{- end -}}
