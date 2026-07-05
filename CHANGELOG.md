# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.3.0] — 2026-07-05

Every change in this release was verified against a real kind cluster deployment (not just `helm lint`/`helm template`) — see the individual entries for what was specifically exercised.

### Added

**High Availability** — Prometheus and Alertmanager are now `StatefulSet`s (were `Deployment`s) with one PVC per replica via `volumeClaimTemplates`, instead of a single shared PVC that made `replicaCount > 1` unsafe. Alertmanager replicas form a real gossip cluster (`--cluster.peer`, headless Service for peer discovery) so duplicate alerts from independent Prometheus replicas get deduplicated into a single notification instead of paging once per replica. Prometheus pushes every alert to every Alertmanager replica directly (not through a load-balanced Service), the standard Prometheus-recommended HA pattern. Verified live: scaled to `prometheus.replicaCount: 2` / `alertmanager.replicaCount: 2`, confirmed both StatefulSets reached `2/2` ready with independent PVCs, and confirmed via `/api/v2/status` that the Alertmanager cluster reached `"ready"` with both replicas listed as gossip peers. Default `replicaCount: 1` for both keeps today's footprint unchanged — this is opt-in. See [High Availability](README.md#high-availability) and the **Changed** entry below for the PVC-naming migration note.

**Authenticated-endpoint monitoring** — targets can now set `headers`, `bearerToken`, or `basicAuth`, and Monitoring Pack generates a dedicated Blackbox Exporter module carrying those credentials automatically (previously required hand-editing the Blackbox ConfigMap). Verified live: deployed a target with a custom `X-API-Key` header against a real header-echo service and confirmed the exact header value arrived at the target and `probe_success` reported correctly.

**Escalation policies** — `alerts.escalation` adds a generic meta-alert (`CriticalAlertEscalation`) over Prometheus's own `ALERTS` metric: any alert with `severity: critical` that stays firing past `alerts.escalation.after` additionally notifies a secondary channel (`notifications.escalation.{pagerdutyRoutingKey,opsgenieApiKey,webhookUrl}`) on top of (not instead of) normal critical routing. Implemented once, generically — no per-alert-type duplication — using `label_replace` to preserve the original alert's name as `original_alertname` (Prometheus always overwrites the `alertname` label with the escalation rule's own name). Verified live: triggered real `WebsiteDown`/`TCPConnectionFailed`/`DNSResolutionFailed`/`ErrorBudgetBurnFast` alerts, confirmed each correctly produced a `CriticalAlertEscalation` alert with the right `original_alertname`, and confirmed the escalation webhook received the correct payload.

**Public status page** — `grafana.statusPage.enabled: true` turns on Grafana anonymous Viewer access and points the home page directly at the Website Monitoring Dashboard, for a Better Stack/Statuspage-style public page (combine with `grafana.ingress`). Verified live: confirmed the dashboard returns full data via an unauthenticated request with zero credentials. Documented security trade-off: this is Grafana's org-wide anonymous access, not its newer per-dashboard "public dashboards" feature (which needs a Grafana API call this chart can't make declaratively via Helm) — only enable on a Grafana instance with nothing else in it you'd mind being public. `grafana.statusPage.orgRole` is schema-locked to `"Viewer"` to prevent misconfiguration.

### Changed (migration note for existing installs)

- **PVC naming changed for Prometheus and Alertmanager** as a consequence of the Deployment→StatefulSet conversion above. Existing PVCs (`<release>-monitoring-pack-prometheus`, `<release>-monitoring-pack-alertmanager`) are retained (not deleted) but become orphaned; new pods start with fresh, empty per-replica PVCs (`data-<release>-monitoring-pack-prometheus-0`, etc.). This applies even if you keep `replicaCount: 1`. See [Upgrade](README.md#upgrade) for what this means for existing metric history/notification state and how to back up first if you need continuity.

> Note: the `monitoring-pack.slug` helper argument-order bug and the `.helmignore` dashboard-emptying bug (both caught while testing this batch of work on a real cluster) never reached a tagged release — see them under [1.2.0](#120--2026-07-05) below, which they were fixed against directly.

---

## [1.2.0] — 2026-07-05

### Added

**SLO / Error budget alerting**
- Google SRE workbook-style multi-window multi-burn-rate alerting: `ErrorBudgetBurnFast` (14.4x burn, ~2 min to fire) and `ErrorBudgetBurnSlow` (6x burn, ~15 min to fire)
- `instance:slo_error_budget_remaining:ratio` recording rule — error budget remaining as a percentage, configurable via `slo.objectivePercent` and `slo.window`
- New Grafana dashboard row: Error Budget Remaining (gauge + trend) and an SLO Compliance table sorted worst-first for fast triage

**Alerting — new receivers & maintenance windows**
- PagerDuty (`notifications.pagerduty`), Opsgenie (`notifications.opsgenie`), and a generic webhook receiver (`notifications.webhook`, with optional basic auth) for incident-management integrations not natively supported
- Native maintenance windows (`maintenanceWindows`) using Alertmanager's `time_intervals`/`mute_time_intervals` — silence notification delivery during planned maintenance with no extra components

**Multi-cluster / scale-out**
- `prometheus.remoteWrite` — forward samples to Thanos, Mimir, Cortex, Grafana Cloud, or a central Prometheus for multi-cluster visibility and long-term storage

**Dashboard**
- New `$target` drill-down variable (multi-select) filters every panel down to one or more monitored targets — previously the dashboard had no way to isolate a single target
- New "Response Latency Percentiles (p50/p95/p99)" panel using `quantile_over_time`

**Developer experience**
- CI now validates rendered `alertmanager.yml` with `amtool check-config` and rendered `prometheus.yml`/rules with `promtool check config`/`check rules` — config-level bugs (see Fixed, below) are no longer invisible to `helm template --debug`
- CI now checks that `dashboards/website-monitoring.json` (manual-import reference copy) hasn't drifted from `files/dashboards/website-monitoring.json` (the deployed copy)

### Fixed

**The auto-provisioned Grafana dashboard has never actually loaded when deployed for real (pre-existing since at least v1.1.0).** `.helmignore` excluded `dashboards/` and `alert-rules/` without anchoring them to the repo root (a leading `/`). `.helmignore` uses gitignore-style matching, where an unanchored `dashboards/` matches a directory of that name at **any** depth — so it silently also excluded `files/dashboards/website-monitoring.json`, the copy actually loaded by `templates/grafana/configmap-dashboard-json.yaml` via `.Files.Get`. The result: `.Files.Get` silently returned `""`, the ConfigMap shipped with an empty `website-monitoring.json`, and Grafana logged `failed to load dashboard ... error=EOF` on every provisioning tick — the dashboard just never appeared, with no error surfaced anywhere in `helm install`/`helm template` output. Caught only by deploying to a real kind cluster and checking Grafana's dashboard list via its API — `helm template` shows the ConfigMap key is present, not that its value rendered empty. Fixed by anchoring both patterns (`/dashboards/`, `/alert-rules/`) to the repo root. **If you're running an older release of this chart, this affects you too** — `helm upgrade` to this version to pick up the fix.

**DNS probes were checking the wrong thing** — `dnsTargets` was documented as "verify a hostname resolves correctly," but blackbox_exporter's DNS prober treats the scrape `target` as the DNS *server* to query and the module's `query_name` as the fixed domain to resolve. The chart pointed `target` at the user's own domain while hard-coding `query_name: google.com`, so every DNS check was silently querying the wrong server for the wrong name. Fixed by generating one Blackbox Exporter module per DNS target (`dns-<name>`, with `query_name` set correctly) and scraping it against a real resolver (`dns.defaultResolver`, override per-target with `resolver:`). Also newly supported in ServiceMonitor and Probe CRD (operator) mode, where DNS targets were previously not wired up at all. Verified end-to-end on a real kind cluster: a DNS target resolved via the cluster's own CoreDNS correctly reports `probe_success 1`, and a nonexistent domain correctly reports `0` and fires `DNSResolutionFailed`.

**Slack + Discord enabled together produced an invalid Alertmanager config** — both channels are implemented via Alertmanager's `slack_configs` (Discord accepts it via a `/slack` webhook suffix), so enabling both emitted two `slack_configs:` keys in the same receiver, which Alertmanager rejects at startup. `helm template --debug` never caught this because it only renders YAML, it doesn't validate the embedded `alertmanager.yml` against Alertmanager's own schema — now fixed by merging both into a single `slack_configs` list, and CI validates the rendered config with `amtool`.

**`DNSResolutionFailed` alert and the "DNS Lookup Time" dashboard panel** referenced the now-obsolete single `job="blackbox-dns"` label; updated to `job=~"blackbox-dns.*"` to match the new per-target DNS job names (see above).

**The name-sanitizing `slug` helper (introduced in this release for per-target DNS/HTTP job naming) initially had Sprig's `regexReplaceAll` argument order backwards** (`regexReplaceAll(regex, replacement)` piped-in, instead of the correct `regexReplaceAll(regex, subject, replacement)`), which silently produced an **empty string** for every target name — turning two-or-more `dnsTargets` into duplicate `dns-` module/job names and crash-looping both Blackbox Exporter (`error parsing config file: ... mapping key "dns-" already defined`) and Prometheus (`found multiple scrape configs with job name "blackbox-dns-"`). Never shipped: caught in this same testing pass by deploying two DNS targets to a real cluster and watching both pods crash-loop. Fixed and re-verified with the real blackbox_exporter/Prometheus binaries (`--config.check`, `promtool check config`) before redeploying.

### Changed (security hardening — opt-in required)

- **Kubernetes pod auto-discovery is now opt-in** (`podMonitoring.enabled`, default `false`). Previously, a cluster-wide `ClusterRole` granting read access to `nodes`, `nodes/proxy`, `pods`, `services`, and `configmaps` was created unconditionally, even though scraping annotated pods is a bonus feature unrelated to this chart's core job (external website/SSL/TCP/DNS probing) and was undocumented in the README. If you relied on this scrape job, set `podMonitoring.enabled: true` (namespace-scoped `Role` by default, or `podMonitoring.namespaces: ["*"]` for the previous cluster-wide behavior).
- **NetworkPolicy TCP egress ports are now derived from `tcpTargets`** instead of a hardcoded guess-list (22/25/3306/5432/6379) — custom ports no longer need a manual NetworkPolicy override. ICMP egress (when `icmpTargets` is set) now explicitly allows all egress with a documented comment, since NetworkPolicy v1 cannot filter by ICMP protocol — previously ICMP probes silently failed whenever `networkPolicy.enabled: true`.

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
