{{/*
Expand the name of the chart.
*/}}
{{- define "monitoring-pack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited.
*/}}
{{- define "monitoring-pack.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart label — name + version.
*/}}
{{- define "monitoring-pack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Global environment / team / application labels.
These appear on every resource when set in values.global.
*/}}
{{- define "monitoring-pack.globalLabels" -}}
{{- if .Values.global.environment }}
environment: {{ .Values.global.environment | quote }}
{{- end }}
{{- if .Values.global.team }}
team: {{ .Values.global.team | quote }}
{{- end }}
{{- if .Values.global.application }}
application: {{ .Values.global.application | quote }}
{{- end }}
{{- end }}

{{/*
Common labels applied to every resource.
*/}}
{{- define "monitoring-pack.labels" -}}
helm.sh/chart: {{ include "monitoring-pack.chart" . }}
{{ include "monitoring-pack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- include "monitoring-pack.globalLabels" . }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels — used in matchLabels and must be immutable post-deploy.
*/}}
{{- define "monitoring-pack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "monitoring-pack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Resolve the namespace to deploy into.
*/}}
{{- define "monitoring-pack.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "monitoring-pack.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "monitoring-pack.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Sanitize a human-readable target name into a safe identifier for use in
Prometheus job names and Blackbox Exporter module keys.
*/}}
{{- define "monitoring-pack.slug" -}}
{{- $s := . | lower | replace " " "-" | replace "_" "-" -}}
{{- regexReplaceAll "[^a-z0-9-]" $s "" -}}
{{- end }}

{{/*
Whether a target (from .Values.targets) has authentication configured.
Uses "dig" because .basicAuth is entirely absent (nil) for targets that
don't set it — a direct .basicAuth.username access panics in that case.
*/}}
{{- define "monitoring-pack.target.hasAuth" -}}
{{- $basicUser := dig "basicAuth" "username" "" . -}}
{{- if or .headers .bearerToken $basicUser }}true{{- end -}}
{{- end }}

{{/* ── Per-component name helpers ─────────────────────────────────────────── */}}

{{- define "monitoring-pack.prometheus.fullname" -}}
{{- printf "%s-prometheus" (include "monitoring-pack.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "monitoring-pack.grafana.fullname" -}}
{{- printf "%s-grafana" (include "monitoring-pack.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "monitoring-pack.alertmanager.fullname" -}}
{{- printf "%s-alertmanager" (include "monitoring-pack.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "monitoring-pack.blackbox.fullname" -}}
{{- printf "%s-blackbox" (include "monitoring-pack.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Name of the Secret holding Grafana admin credentials.
Returns existingSecret if set, otherwise the chart-managed secret name.
*/}}
{{- define "monitoring-pack.grafana.secretName" -}}
{{- default (include "monitoring-pack.grafana.fullname" .) .Values.grafana.existingSecret }}
{{- end }}

{{/* ── Per-component selector labels ──────────────────────────────────────── */}}

{{- define "monitoring-pack.prometheus.selectorLabels" -}}
app.kubernetes.io/name: {{ include "monitoring-pack.name" . }}-prometheus
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: prometheus
{{- end }}

{{- define "monitoring-pack.grafana.selectorLabels" -}}
app.kubernetes.io/name: {{ include "monitoring-pack.name" . }}-grafana
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: grafana
{{- end }}

{{- define "monitoring-pack.alertmanager.selectorLabels" -}}
app.kubernetes.io/name: {{ include "monitoring-pack.name" . }}-alertmanager
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: alertmanager
{{- end }}

{{- define "monitoring-pack.blackbox.selectorLabels" -}}
app.kubernetes.io/name: {{ include "monitoring-pack.name" . }}-blackbox
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: blackbox-exporter
{{- end }}

{{/* ── In-cluster service addresses ────────────────────────────────────────── */}}

{{- define "monitoring-pack.prometheus.address" -}}
{{- printf "http://%s:%d" (include "monitoring-pack.prometheus.fullname" .) (.Values.prometheus.service.port | int) }}
{{- end }}

{{- define "monitoring-pack.alertmanager.address" -}}
{{- printf "%s:%d" (include "monitoring-pack.alertmanager.fullname" .) (.Values.alertmanager.service.port | int) }}
{{- end }}

{{- define "monitoring-pack.blackbox.address" -}}
{{- printf "%s:%d" (include "monitoring-pack.blackbox.fullname" .) (.Values.blackboxExporter.service.port | int) }}
{{- end }}

{{/*
Resolve the Blackbox Exporter prober URL for Probe CRD.
Uses probe.proberUrl if set; otherwise the in-cluster service address.
*/}}
{{- define "monitoring-pack.probe.proberUrl" -}}
{{- if .Values.probe.proberUrl }}
{{- .Values.probe.proberUrl }}
{{- else }}
{{- include "monitoring-pack.blackbox.address" . }}
{{- end }}
{{- end }}

{{/* ── Alertmanager notification config snippets ───────────────────────────── */}}

{{/*
Slack and Discord both speak Alertmanager's slack_configs API (Discord accepts
it via the /slack webhook suffix). Alertmanager rejects a receiver with two
"slack_configs:" keys, so when both channels are enabled they MUST share a
single slack_configs list rather than each emitting their own top-level key.
*/}}
{{- define "monitoring-pack.slackLikeConfigs" -}}
{{- if or .Values.notifications.slack.enabled .Values.notifications.discord.enabled }}
slack_configs:
  {{- if .Values.notifications.slack.enabled }}
  - api_url: {{ .Values.notifications.slack.webhookUrl | quote }}
    channel: {{ .Values.notifications.slack.channel | quote }}
    username: {{ .Values.notifications.slack.username | quote }}
    icon_emoji: ":satellite_antenna:"
    send_resolved: true
    color: |-
      {{ "{{" }} if eq .Status "firing" {{ "}}" }}{{ "{{" }} if eq (index .CommonLabels "severity") "critical" {{ "}}" }}#E53E3E{{ "{{" }} else {{ "}}" }}#DD6B20{{ "{{" }} end {{ "}}" }}{{ "{{" }} else {{ "}}" }}#38A169{{ "{{" }} end {{ "}}" }}
    title: |-
      {{ "{{" }} if eq .Status "firing" {{ "}}" }}{{ "{{" }} if eq (index .CommonLabels "severity") "critical" {{ "}}" }}🔴{{ "{{" }} else {{ "}}" }}🟡{{ "{{" }} end {{ "}}" }}{{ "{{" }} else {{ "}}" }}✅{{ "{{" }} end {{ "}}" }} [{{ "{{" }} .Status | toUpper {{ "}}" }}{{ "{{" }} if eq .Status "firing" {{ "}}" }}:{{ "{{" }} .Alerts.Firing | len {{ "}}" }}{{ "{{" }} end {{ "}}" }}] {{ "{{" }} .CommonLabels.alertname {{ "}}" }}
    pretext: |-
      {{ "{{" }} if eq .Status "firing" {{ "}}" }}{{ "{{" }} if eq (index .CommonLabels "severity") "critical" {{ "}}" }}:rotating_light:  *Critical alert — immediate action required*{{ "{{" }} else {{ "}}" }}:warning:  *Warning — please investigate*{{ "{{" }} end {{ "}}" }}{{ "{{" }} else {{ "}}" }}:white_check_mark:  *Resolved — system is back to normal*{{ "{{" }} end {{ "}}" }}
    text: |-
      {{ "{{" }} range .Alerts {{ "}}" }}
      :globe_with_meridians:  *Target* `{{ "{{" }} .Labels.instance {{ "}}" }}`
      {{ "{{" }} if eq .Labels.severity "critical" {{ "}}" }}:red_circle:{{ "{{" }} else {{ "}}" }}:large_yellow_circle:{{ "{{" }} end {{ "}}" }}  *Severity* `{{ "{{" }} .Labels.severity | toUpper {{ "}}" }}`
      :page_facing_up:  *Summary* {{ "{{" }} .Annotations.summary {{ "}}" }}
      :pencil:  *Detail* {{ "{{" }} .Annotations.description {{ "}}" }}
      :clock3:  *Since* `{{ "{{" }} .StartsAt.Format "Jan 02, 2006 15:04 UTC" {{ "}}" }}`
      :label:  *Job* `{{ "{{" }} .Labels.job {{ "}}" }}`
      {{ "{{" }} end {{ "}}" }}
    footer: "Monitoring Pack"
  {{- end }}
  {{- if .Values.notifications.discord.enabled }}
  - api_url: {{ .Values.notifications.discord.webhookUrl | quote }}
    send_resolved: true
    title: |-
      [{{ "{{" }} .Status | toUpper {{ "}}" }}] {{ "{{" }} .CommonLabels.alertname {{ "}}" }}
    text: |-
      {{ "{{" }} range .Alerts {{ "}}" }}Target: {{ "{{" }} .Labels.instance {{ "}}" }} | {{ "{{" }} .Annotations.summary {{ "}}" }}{{ "{{" }} end {{ "}}" }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "monitoring-pack.emailConfig" -}}
{{- if .Values.notifications.email.enabled }}
email_configs:
  - to: {{ .Values.notifications.email.to | quote }}
    send_resolved: true
    html: |-
      <h2>{{ "{{" }} .Status | toUpper {{ "}}" }}: {{ "{{" }} .CommonLabels.alertname {{ "}}" }}</h2>
      {{ "{{" }} range .Alerts {{ "}}" }}
      <p><b>Target:</b> {{ "{{" }} .Labels.instance {{ "}}" }}<br/>
      <b>Severity:</b> {{ "{{" }} .Labels.severity {{ "}}" }}<br/>
      <b>Summary:</b> {{ "{{" }} .Annotations.summary {{ "}}" }}<br/>
      <b>Description:</b> {{ "{{" }} .Annotations.description {{ "}}" }}</p>
      {{ "{{" }} end {{ "}}" }}
{{- end }}
{{- end }}

{{- define "monitoring-pack.teamsConfig" -}}
{{- if .Values.notifications.teams.enabled }}
msteams_configs:
  - webhook_url: {{ .Values.notifications.teams.webhookUrl | quote }}
    send_resolved: true
    title: |-
      [{{ "{{" }} .Status | toUpper {{ "}}" }}] {{ "{{" }} .CommonLabels.alertname {{ "}}" }}
    text: |-
      {{ "{{" }} range .Alerts {{ "}}" }}**{{ "{{" }} .Labels.instance {{ "}}" }}** — {{ "{{" }} .Annotations.summary {{ "}}" }}{{ "{{" }} end {{ "}}" }}
{{- end }}
{{- end }}

{{- define "monitoring-pack.telegramConfig" -}}
{{- if .Values.notifications.telegram.enabled }}
telegram_configs:
  - bot_token: {{ .Values.notifications.telegram.botToken | quote }}
    chat_id: {{ .Values.notifications.telegram.chatId }}
    send_resolved: true
    parse_mode: HTML
    message: |-
      <b>[{{ "{{" }} .Status | toUpper {{ "}}" }}] {{ "{{" }} .CommonLabels.alertname {{ "}}" }}</b>
      {{ "{{" }} range .Alerts {{ "}}" }}
      🎯 <b>Target:</b> {{ "{{" }} .Labels.instance {{ "}}" }}
      📋 <b>Summary:</b> {{ "{{" }} .Annotations.summary {{ "}}" }}
      {{ "{{" }} end {{ "}}" }}
{{- end }}
{{- end }}

{{- define "monitoring-pack.pagerdutyConfig" -}}
{{- if .Values.notifications.pagerduty.enabled }}
pagerduty_configs:
  - routing_key: {{ .Values.notifications.pagerduty.routingKey | quote }}
    send_resolved: true
    client: "Monitoring Pack"
    client_url: '{{ "{{" }} .ExternalURL {{ "}}" }}'
    severity: |-
      {{ "{{" }} if eq (index .CommonLabels {{ .Values.notifications.pagerduty.severityLabel | quote }}) "critical" {{ "}}" }}critical{{ "{{" }} else {{ "}}" }}warning{{ "{{" }} end {{ "}}" }}
    description: |-
      [{{ "{{" }} .Status | toUpper {{ "}}" }}] {{ "{{" }} .CommonLabels.alertname {{ "}}" }} — {{ "{{" }} .CommonAnnotations.summary {{ "}}" }}
    details:
      target: '{{ "{{" }} .CommonLabels.instance {{ "}}" }}'
      severity: '{{ "{{" }} .CommonLabels.severity {{ "}}" }}'
      summary: '{{ "{{" }} .CommonAnnotations.summary {{ "}}" }}'
      description: '{{ "{{" }} .CommonAnnotations.description {{ "}}" }}'
{{- end }}
{{- end }}

{{- define "monitoring-pack.opsgenieConfig" -}}
{{- if .Values.notifications.opsgenie.enabled }}
opsgenie_configs:
  - api_key: {{ .Values.notifications.opsgenie.apiKey | quote }}
    api_url: {{ .Values.notifications.opsgenie.apiUrl | quote }}
    send_resolved: true
    message: |-
      [{{ "{{" }} .Status | toUpper {{ "}}" }}] {{ "{{" }} .CommonLabels.alertname {{ "}}" }}
    description: |-
      {{ "{{" }} range .Alerts {{ "}}" }}Target: {{ "{{" }} .Labels.instance {{ "}}" }} — {{ "{{" }} .Annotations.summary {{ "}}" }}
      {{ "{{" }} end {{ "}}" }}
    priority: |-
      {{ "{{" }} if eq .CommonLabels.severity "critical" {{ "}}" }}P1{{ "{{" }} else {{ "}}" }}P3{{ "{{" }} end {{ "}}" }}
    tags: '{{ "{{" }} .CommonLabels.severity {{ "}}" }},{{ "{{" }} .CommonLabels.type {{ "}}" }},monitoring-pack'
{{- end }}
{{- end }}

{{- define "monitoring-pack.webhookConfig" -}}
{{- if .Values.notifications.webhook.enabled }}
webhook_configs:
  - url: {{ .Values.notifications.webhook.url | quote }}
    send_resolved: true
    {{- if .Values.notifications.webhook.basicAuth.username }}
    http_config:
      basic_auth:
        username: {{ .Values.notifications.webhook.basicAuth.username | quote }}
        password: {{ .Values.notifications.webhook.basicAuth.password | quote }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
Notification configs for the escalation receiver (alerts.escalation.enabled).
Severity is always "critical" here — escalation only ever applies to
already-critical alerts that have stayed unresolved too long.
*/}}
{{- define "monitoring-pack.escalationConfigs" -}}
{{- if .Values.notifications.escalation.pagerdutyRoutingKey }}
pagerduty_configs:
  - routing_key: {{ .Values.notifications.escalation.pagerdutyRoutingKey | quote }}
    send_resolved: true
    client: "Monitoring Pack"
    client_url: '{{ "{{" }} .ExternalURL {{ "}}" }}'
    severity: critical
    description: |-
      [ESCALATED] {{ "{{" }} .CommonLabels.original_alertname {{ "}}" }} — unresolved for over {{ .Values.alerts.escalation.after }}
    details:
      target: '{{ "{{" }} .CommonLabels.instance {{ "}}" }}'
      original_alert: '{{ "{{" }} .CommonLabels.original_alertname {{ "}}" }}'
{{- end }}
{{- if .Values.notifications.escalation.opsgenieApiKey }}
opsgenie_configs:
  - api_key: {{ .Values.notifications.escalation.opsgenieApiKey | quote }}
    send_resolved: true
    message: |-
      [ESCALATED] {{ "{{" }} .CommonLabels.original_alertname {{ "}}" }} on {{ "{{" }} .CommonLabels.instance {{ "}}" }}
    priority: P1
{{- end }}
{{- if .Values.notifications.escalation.webhookUrl }}
webhook_configs:
  - url: {{ .Values.notifications.escalation.webhookUrl | quote }}
    send_resolved: true
{{- end }}
{{- end }}

{{/*
List of maintenance-window names for a route's mute_time_intervals field.
Renders nothing if no maintenance windows are configured.
*/}}
{{- define "monitoring-pack.muteTimeIntervals" -}}
{{- if .Values.maintenanceWindows }}
mute_time_intervals:
  {{- range .Values.maintenanceWindows }}
  - {{ .name | quote }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Alertmanager time_intervals block generated from .Values.maintenanceWindows.
Each entry becomes one named time_intervals group referenced by
mute_time_intervals on the root route.
*/}}
{{- define "monitoring-pack.timeIntervals" -}}
{{- range .Values.maintenanceWindows }}
- name: {{ .name | quote }}
  time_intervals:
    - {{- if .times }}
      times:
        {{- toYaml .times | nindent 8 }}
      {{- end }}
      {{- if .weekdays }}
      weekdays: {{ toJson .weekdays }}
      {{- end }}
      {{- if .daysOfMonth }}
      days_of_month: {{ toJson .daysOfMonth }}
      {{- end }}
      {{- if .months }}
      months: {{ toJson .months }}
      {{- end }}
      {{- if .years }}
      years: {{ toJson .years }}
      {{- end }}
      {{- if .location }}
      location: {{ .location | quote }}
      {{- end }}
{{- end }}
{{- end }}
