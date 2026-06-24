# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] — 2026-06-24

### Fixed

**Alert reliability**
- `scrapeTimeout: 20s` — was 10s, which was less than blackbox module timeout (30s), causing false `probe_success=0` and spurious alerts
- All blackbox module timeouts reduced to `15s` (must be < scrapeTimeout); scrapeInterval remains `60s`
- Alert `for:` durations corrected: `WebsiteDown` 1m, `SlowResponseTimeWarning` 3m, `SlowResponseTimeCritical` 1m, `SSLCertExpiringSoon` 30m
- Alert group `interval` reduced to `30s` (was 60s) for faster rule evaluation
- `UnexpectedHTTPStatus` now included in WebsiteDown inhibition rule (was only SlowResponseTime)
- SSL alert route: `continue: false` (was `true` — caused each SSL alert to be sent twice)
- `resolveTimeout: 2m` (was 5m — caused RESOLVED alerts to be delayed or missed after pod restarts)
- `groupBy: ["alertname"]` prevents alert fragmentation across instances

**Persistence**
- Prometheus, Grafana, and Alertmanager PVCs now annotated with `helm.sh/resource-policy: keep` — data survives `helm upgrade` and `helm uninstall`
- Removed erroneous `--set persistence.enabled=false` from all upgrade examples

**Configuration**
- `blackbox-ssl` Prometheus scrape job wrapped in conditional — no longer rendered when no HTTPS targets exist (was producing invalid Prometheus config)
- Per-target scrape interval now correctly applied — targets with custom `interval` or `module` get their own Prometheus scrape job
- `disableDeletion: true` on Grafana dashboard provisioner — users can no longer accidentally delete built-in dashboards via the UI
- `prometheusVersion` in Grafana datasource now derived dynamically from `prometheus.image.tag` (was hardcoded to 2.51.0)
- ServiceMonitor SSL: only rendered when at least one HTTPS target exists (empty `endpoints:` was invalid)
- `checksum/config` annotations added to Blackbox Exporter and Grafana deployments — pod restarts automatically on ConfigMap/Secret changes

### Improved

**Dashboard (v4)**
- Stat panels reordered: Down → Up → Availability → Response Time → SSL Days → Total (most critical first)
- Sparkline graphs on all stat panels; larger text (44px) for at-a-glance readability
- Row headers with emojis for visual separation
- Website Status table: `✓ UP` / `✗ DOWN` value mappings with colour-background cells

**Slack alerts**
- Rich message format: coloured sidebar (red/orange/green by severity), emoji fields, pretext banner
- `send_resolved: true` — RESOLVED messages now sent reliably

**Schema**
- Added `prometheus.scrapeTimeout` to `values.schema.json`
- Removed fragile `if/then` conditional from Slack schema section (caused `helm lint --strict` failures with empty webhookUrl default)

---

## [1.0.0] — 2024-12-01

### Added

**Core monitoring stack**
- Prometheus v2.51 with configurable retention, scrape intervals, and persistent storage
- Grafana v10.4 with auto-provisioned dashboards and datasources — no manual import needed
- Alertmanager v0.27 with multi-channel routing (Slack, Email, Discord, Teams, Telegram)
- Blackbox Exporter v0.25 with support for HTTP, HTTPS, TCP, DNS, and ICMP probes

**Dashboards**
- Pre-built website monitoring dashboard with 19 panels
- State Timeline panel showing UP/DOWN history per target
- HTTP phase breakdown (resolve, connect, TLS, processing, transfer)
- SSL certificate expiry timeline and issuer table
- TLS version info panel
- Availability summary (1h, 6h, 24h, 7d, 30d windows)
- TCP / DNS / ICMP monitoring row

**Alert rules (12 rules)**
- `WebsiteDown` — target unreachable for 2+ minutes
- `SlowResponseTimeWarning` — response > 2s for 5+ minutes
- `SlowResponseTimeCritical` — response > 5s for 2+ minutes
- `UnexpectedHTTPStatus` — non-2xx/3xx status code
- `SSLCertExpiringSoon` — cert expires in < 30 days
- `SSLCertExpiringCritical` — cert expires in < 7 days
- `SSLCertExpired` — cert has already expired
- `SSLProbeFailed` — cannot establish TLS connection
- `TCPConnectionFailed` — TCP port unreachable
- `DNSResolutionFailed` — DNS lookup failing
- `ICMPProbeFailed` — ICMP ping failing
- `BlackboxExporterDown` — the probe engine is down

**Prometheus Operator integration**
- Optional `ServiceMonitor` CRD for kube-prometheus-stack integration
- Optional `PrometheusRule` CRD for externalising alert rules
- Optional `Probe` CRD (prometheus-operator v0.47+) for native blackbox probing

**Security**
- All containers run as non-root (`runAsNonRoot: true`, UID 65534 / 472)
- `readOnlyRootFilesystem: true` on all containers (tmpfs at `/tmp` where needed)
- `allowPrivilegeEscalation: false` on all containers
- All Linux capabilities dropped (`capabilities.drop: ["ALL"]`)
- `seccompProfile: RuntimeDefault` on all pods
- Support for `existingSecret` to avoid storing Grafana credentials in values.yaml

**Operations**
- Optional `NetworkPolicy` resources for each component
- Optional `PodDisruptionBudget` resources for each component
- Optional `Ingress` for both Grafana and Prometheus
- Helm test pod (`helm test`) that verifies all component health endpoints
- `values.schema.json` for values validation with helpful error messages
- `helm.sh/resource-policy: keep` on all PVCs to prevent accidental data loss

**Global labels**
- `environment`, `team`, and `application` labels propagated to every resource

**CI / CD**
- GitHub Actions pipeline with `helm lint --strict`, `yamllint`, `helm template` (6 scenarios), and optional kind-based integration test

[1.0.0]: https://github.com/your-org/monitoring-pack/releases/tag/v1.0.0
