{{/*
Shared alert rule groups — included by both:
  - templates/prometheus/configmap.yaml   (standalone mode)
  - templates/prometheusrule.yaml         (Prometheus Operator mode)

Usage:
  groups:
  {{- include "monitoring-pack.alertGroups" . | nindent 4 }}
*/}}
{{- define "monitoring-pack.alertGroups" -}}
- name: website-availability
  interval: 30s
  rules:

    # ── Target down ────────────────────────────────────────────────────────────
    - alert: WebsiteDown
      expr: probe_success{job=~"blackbox-http.*"} == 0
      for: {{ .Values.alerts.downFor }}
      labels:
        severity: critical
        type: availability
      annotations:
        summary: "Website down: {{ "{{" }} $labels.instance {{ "}}" }}"
        description: >
          {{ "{{" }} $labels.instance {{ "}}" }} has been unreachable for
          more than {{ .Values.alerts.downFor }}.
          Probe job: {{ "{{" }} $labels.job {{ "}}" }}
        runbook: "Check DNS, firewall, and origin server health."

    # ── Slow response — warning ────────────────────────────────────────────────
    - alert: SlowResponseTimeWarning
      expr: >
        probe_duration_seconds{job=~"blackbox-http.*"}
        > {{ .Values.alerts.responseTime.warning }}
      for: 3m
      labels:
        severity: warning
        type: performance
      annotations:
        summary: "Slow response: {{ "{{" }} $labels.instance {{ "}}" }}"
        description: >
          {{ "{{" }} $labels.instance {{ "}}" }} response time is
          {{ "{{" }} $value | printf "%.2f" {{ "}}" }}s
          (threshold: {{ .Values.alerts.responseTime.warning }}s).

    # ── Slow response — critical ───────────────────────────────────────────────
    - alert: SlowResponseTimeCritical
      expr: >
        probe_duration_seconds{job=~"blackbox-http.*"}
        > {{ .Values.alerts.responseTime.critical }}
      for: 1m
      labels:
        severity: critical
        type: performance
      annotations:
        summary: "Critical response time: {{ "{{" }} $labels.instance {{ "}}" }}"
        description: >
          {{ "{{" }} $labels.instance {{ "}}" }} response time is
          {{ "{{" }} $value | printf "%.2f" {{ "}}" }}s
          (threshold: {{ .Values.alerts.responseTime.critical }}s).

    # ── Unexpected HTTP status code ────────────────────────────────────────────
    # Fires when a server responds (status != 0) but probe still fails.
    # Distinguishes "server returned error code" from "host unreachable".
    # Inhibited by WebsiteDown for same instance (see inhibit_rules).
    - alert: UnexpectedHTTPStatus
      expr: >
        probe_http_status_code{job=~"blackbox-http.*"} >= 400
        and probe_http_status_code{job=~"blackbox-http.*"} != 0
      for: 2m
      labels:
        severity: warning
        type: availability
      annotations:
        summary: "HTTP error {{ "{{" }} $value {{ "}}" }}: {{ "{{" }} $labels.instance {{ "}}" }}"
        description: >
          {{ "{{" }} $labels.instance {{ "}}" }} returned HTTP {{ "{{" }} $value {{ "}}" }}.
          The server is reachable but returning an error response.

- name: ssl-certificates
  interval: 300s
  rules:

    # ── SSL expiring — warning ─────────────────────────────────────────────────
    - alert: SSLCertExpiringSoon
      expr: >
        (probe_ssl_earliest_cert_expiry{job="blackbox-ssl"} - time()) / 86400
        < {{ .Values.alerts.ssl.warningDays }}
      for: 30m
      labels:
        severity: warning
        type: ssl
      annotations:
        summary: "SSL cert expiring: {{ "{{" }} $labels.instance {{ "}}" }}"
        description: >
          SSL certificate for {{ "{{" }} $labels.instance {{ "}}" }} expires in
          {{ "{{" }} $value | printf "%.0f" {{ "}}" }} days
          (warning threshold: {{ .Values.alerts.ssl.warningDays }} days).
        runbook: "Renew the SSL certificate before expiry."

    # ── SSL expiring — critical ────────────────────────────────────────────────
    - alert: SSLCertExpiringCritical
      expr: >
        (probe_ssl_earliest_cert_expiry{job="blackbox-ssl"} - time()) / 86400
        < {{ .Values.alerts.ssl.criticalDays }}
      for: 30m
      labels:
        severity: critical
        type: ssl
      annotations:
        summary: "SSL cert critically close to expiry: {{ "{{" }} $labels.instance {{ "}}" }}"
        description: >
          SSL certificate for {{ "{{" }} $labels.instance {{ "}}" }} expires in
          {{ "{{" }} $value | printf "%.0f" {{ "}}" }} days!
          Immediate renewal required.

    # ── SSL expired ────────────────────────────────────────────────────────────
    - alert: SSLCertExpired
      expr: >
        (probe_ssl_earliest_cert_expiry{job="blackbox-ssl"} - time()) / 86400
        <= 0
      for: 0m
      labels:
        severity: critical
        type: ssl
      annotations:
        summary: "SSL cert EXPIRED: {{ "{{" }} $labels.instance {{ "}}" }}"
        description: >
          SSL certificate for {{ "{{" }} $labels.instance {{ "}}" }} has EXPIRED.
          Users will see security warnings. Renew immediately.

    # ── SSL probe failure ──────────────────────────────────────────────────────
    - alert: SSLProbeFailed
      expr: probe_success{job="blackbox-ssl"} == 0
      for: 5m
      labels:
        severity: critical
        type: ssl
      annotations:
        summary: "SSL probe failed: {{ "{{" }} $labels.instance {{ "}}" }}"
        description: >
          Cannot establish TLS connection to {{ "{{" }} $labels.instance {{ "}}" }}.
          The certificate may be invalid or the host unreachable.

- name: tcp-dns-icmp
  interval: 60s
  rules:

    - alert: TCPConnectionFailed
      expr: probe_success{job="blackbox-tcp"} == 0
      for: 2m
      labels:
        severity: critical
        type: connectivity
      annotations:
        summary: "TCP connection failed: {{ "{{" }} $labels.instance {{ "}}" }}"
        description: "Cannot connect to {{ "{{" }} $labels.instance {{ "}}" }} via TCP."

    - alert: DNSResolutionFailed
      expr: probe_success{job="blackbox-dns"} == 0
      for: 2m
      labels:
        severity: critical
        type: dns
      annotations:
        summary: "DNS resolution failed: {{ "{{" }} $labels.instance {{ "}}" }}"
        description: "DNS resolution failed for {{ "{{" }} $labels.instance {{ "}}" }}."

    - alert: ICMPProbeFailed
      expr: probe_success{job="blackbox-icmp"} == 0
      for: 5m
      labels:
        severity: warning
        type: connectivity
      annotations:
        summary: "Ping failed: {{ "{{" }} $labels.instance {{ "}}" }}"
        description: "ICMP probe to {{ "{{" }} $labels.instance {{ "}}" }} is failing."

- name: monitoring-pack-health
  interval: 60s
  rules:

    - alert: BlackboxExporterDown
      expr: up{job="blackbox-exporter"} == 0
      for: 2m
      labels:
        severity: critical
        type: internal
      annotations:
        summary: "Blackbox Exporter is down"
        description: >
          The Blackbox Exporter is unreachable. All website probes have stopped.
          Release: {{ .Release.Name }}, Namespace: {{ include "monitoring-pack.namespace" . }}.
{{- end }}
