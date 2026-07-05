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
      # DNS targets each get their own job (blackbox-dns-<name>) since each
      # needs a distinct query_name module — see blackbox/configmap.yaml.
      expr: probe_success{job=~"blackbox-dns.*"} == 0
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

{{- if .Values.alerts.escalation.enabled }}

    # ── Escalation — generic meta-alert over any critical alert ───────────────
    # Matches Prometheus's own ALERTS metric rather than duplicating this
    # rule per alert type: any alert with severity="critical" that keeps
    # firing past alerts.escalation.after gets escalated. label_replace
    # preserves the original alertname as "original_alertname" because
    # Prometheus always overwrites the "alertname" label with this rule's
    # own name ("CriticalAlertEscalation") on the resulting alert.
    - alert: CriticalAlertEscalation
      expr: >
        label_replace(
          ALERTS{alertstate="firing", severity="critical", alertname!="CriticalAlertEscalation"},
          "original_alertname", "$1", "alertname", "(.*)"
        )
      for: {{ .Values.alerts.escalation.after }}
      labels:
        severity: critical
        type: escalation
        escalation: "true"
      annotations:
        summary: "ESCALATION: {{ "{{" }} $labels.original_alertname {{ "}}" }} unresolved for over {{ .Values.alerts.escalation.after }}"
        description: >
          {{ "{{" }} $labels.original_alertname {{ "}}" }} on {{ "{{" }} $labels.instance {{ "}}" }}
          has remained critical for more than {{ .Values.alerts.escalation.after }} without
          resolving. Escalating to the secondary on-call channel.
{{- end }}

{{- if .Values.slo.enabled }}
{{- $objective := .Values.slo.objectivePercent | float64 }}
{{- $errorBudget := divf (subf 100.0 $objective) 100.0 }}
{{- $fastBurnRatio := subf 1.0 (mulf 14.4 $errorBudget) }}
{{- $slowBurnRatio := subf 1.0 (mulf 6.0 $errorBudget) }}

- name: slo-error-budget
  interval: 60s
  rules:

    # ── Rolling success-ratio recording rules ─────────────────────────────────
    # Multi-window multi-burn-rate alerting (Google SRE workbook method).
    # Burn-rate multipliers (14.4x / 6x) are the industry-standard values
    # calibrated for a 30-day SLO window regardless of slo.window below.
    - record: instance:probe_success:ratio_rate5m
      expr: avg_over_time(probe_success{job=~"blackbox-http.*"}[5m])

    - record: instance:probe_success:ratio_rate30m
      expr: avg_over_time(probe_success{job=~"blackbox-http.*"}[30m])

    - record: instance:probe_success:ratio_rate1h
      expr: avg_over_time(probe_success{job=~"blackbox-http.*"}[1h])

    - record: instance:probe_success:ratio_rate6h
      expr: avg_over_time(probe_success{job=~"blackbox-http.*"}[6h])

    - record: instance:probe_success:ratio_rate_window
      expr: avg_over_time(probe_success{job=~"blackbox-http.*"}[{{ .Values.slo.window }}])

    # Error budget remaining, as a fraction of the total {{ .Values.slo.objectivePercent }}%
    # budget over the {{ .Values.slo.window }} window. 1.0 = full budget, 0 = exhausted,
    # negative = objective already missed.
    - record: instance:slo_error_budget_remaining:ratio
      expr: >
        1 - ((1 - instance:probe_success:ratio_rate_window) / {{ $errorBudget }})

    # ── Fast burn — page-worthy: ~2 min to fire ───────────────────────────────
    - alert: ErrorBudgetBurnFast
      expr: >
        instance:probe_success:ratio_rate1h < {{ $fastBurnRatio }}
        and
        instance:probe_success:ratio_rate5m < {{ $fastBurnRatio }}
      for: 2m
      labels:
        severity: critical
        type: slo
      annotations:
        summary: "Fast error-budget burn: {{ "{{" }} $labels.instance {{ "}}" }}"
        description: >
          {{ "{{" }} $labels.instance {{ "}}" }} is burning its {{ .Values.slo.objectivePercent }}%
          availability error budget at more than 14.4x the sustainable rate
          (sustained over both the 1h and 5m windows). Left unchecked, this
          exhausts the entire {{ .Values.slo.window }} error budget in about 2 days.
        runbook: "Sustained outage or severe degradation — treat like WebsiteDown."

    # ── Slow burn — ticket-worthy: ~15 min to fire ────────────────────────────
    - alert: ErrorBudgetBurnSlow
      expr: >
        instance:probe_success:ratio_rate6h < {{ $slowBurnRatio }}
        and
        instance:probe_success:ratio_rate30m < {{ $slowBurnRatio }}
      for: 15m
      labels:
        severity: warning
        type: slo
      annotations:
        summary: "Slow error-budget burn: {{ "{{" }} $labels.instance {{ "}}" }}"
        description: >
          {{ "{{" }} $labels.instance {{ "}}" }} is burning its {{ .Values.slo.objectivePercent }}%
          availability error budget at more than 6x the sustainable rate
          (sustained over both the 6h and 30m windows). Investigate before it
          becomes critical.
        runbook: "Check recent deploys, dependency health, and response-time trends."
{{- end }}
{{- end }}
