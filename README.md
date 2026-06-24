# Monitoring Pack

[![Helm v3](https://img.shields.io/badge/helm-v3-blue?logo=helm)](https://helm.sh)
[![Kubernetes 1.25+](https://img.shields.io/badge/kubernetes-1.25+-blue?logo=kubernetes)](https://kubernetes.io)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![CI](https://github.com/your-org/monitoring-pack/actions/workflows/ci.yml/badge.svg)](https://github.com/your-org/monitoring-pack/actions/workflows/ci.yml)

> Production-ready, self-hosted website and SSL monitoring for Kubernetes.
> One command to deploy. Everything pre-configured. Zero SaaS.

**Monitoring Pack** bundles Prometheus, Grafana, Alertmanager, and Blackbox Exporter into a single Helm chart with pre-built dashboards, alert rules, and notification support for Slack, Email, Discord, Teams, and Telegram. Edit `values.yaml` to add your websites — the chart handles the rest.

---

## Table of Contents

1. [What Does It Do?](#what-does-it-do)
2. [How It Works](#how-it-works)
3. [What Each Component Does](#what-each-component-does)
4. [Prerequisites](#prerequisites)
5. [Quick Start](#quick-start)
6. [Installation](#installation)
   - [Standalone Mode](#standalone-mode-default)
   - [Integration with kube-prometheus-stack](#integration-with-kube-prometheus-stack)
7. [Configuration Guide](#configuration-guide)
   - [Adding Websites](#adding-websites)
   - [Probe Types](#probe-types)
   - [Alert Thresholds](#alert-thresholds)
   - [Environment Labels](#environment-and-team-labels)
   - [Persistent Storage](#persistent-storage)
   - [Exposing Grafana](#exposing-grafana)
8. [Setting Up Notifications](#setting-up-notifications)
   - [Slack](#slack)
   - [Email](#email)
   - [Discord](#discord)
   - [Microsoft Teams](#microsoft-teams)
   - [Telegram](#telegram)
9. [Grafana Dashboard](#grafana-dashboard)
10. [Alert Rules Reference](#alert-rules-reference)
11. [Multiple Environments](#multiple-environments)
12. [Security Hardening](#security-hardening)
13. [Upgrade](#upgrade)
14. [Uninstall](#uninstall)
15. [Troubleshooting](#troubleshooting)
16. [FAQ](#faq)
17. [Dashboard Screenshots](#dashboard-screenshots)
18. [Contributing](#contributing)
19. [Changelog](#changelog)

---

## What Does It Do?

Monitoring Pack checks your websites and APIs every minute and tells you when something is wrong — before your users notice.

| What it monitors | How it tells you |
|-----------------|-----------------|
| Is my website up or down? | Slack, Email, Discord, Teams, Telegram |
| How fast is it responding? | Grafana dashboard + alert if > 2s |
| Is my SSL certificate about to expire? | Alert 30 days before expiry |
| Is my SSL certificate using TLS 1.3? | Dashboard shows TLS version |
| Can I connect to my database port? | TCP probe |
| Does my domain resolve correctly? | DNS probe |
| Can I ping my server? | ICMP probe |

---

## How It Works

```mermaid
graph TB
    subgraph "Your Infrastructure"
        W1["🌐 Website 1\nhttps://example.com"]
        W2["🌐 Website 2\nhttps://api.example.com"]
        W3["🗄️ Database\ndb.example.com:5432"]
    end

    subgraph "Kubernetes Cluster — Monitoring Pack"
        BE["🔍 Blackbox Exporter\n Port 9115\nProbes your services"]
        PM["📊 Prometheus\nPort 9090\nStores & evaluates metrics"]
        AM["🔔 Alertmanager\nPort 9093\nRoutes notifications"]
        GF["📈 Grafana\nPort 3000\nVisual dashboards"]
    end

    subgraph "You"
        SL["Slack"]
        EM["Email"]
        DC["Discord / Teams"]
        TG["Telegram"]
        U["🧑 Browser → Grafana"]
    end

    PM -->|"Probe every 60s"| BE
    BE -->|"HTTP / HTTPS"| W1
    BE -->|"HTTP / HTTPS + SSL check"| W2
    BE -->|"TCP connect"| W3
    PM -->|"Evaluate alert rules"| AM
    AM -->|"Send notification"| SL
    AM --> EM
    AM --> DC
    AM --> TG
    GF -->|"Query metrics"| PM
    U -->|"View dashboards"| GF
```

**The flow in plain English:**
1. **Blackbox Exporter** makes real HTTP requests to your websites, just like a browser would.
2. **Prometheus** asks the Blackbox Exporter "did the probe succeed?" every 60 seconds and saves the result. Alert rules are evaluated every 30 seconds.
3. When a rule fires (e.g., website down for 1 minute), **Alertmanager** sends you a notification within ~10 seconds.
4. **Grafana** reads Prometheus data and shows you beautiful charts and history.

---

## What Each Component Does

### Prometheus
Think of Prometheus as a **time-series database with a brain**. It:
- Scrapes metrics from Blackbox Exporter every 60 seconds
- Stores every data point with a timestamp
- Evaluates alert rules (`if website_down > 2 minutes, fire alert`)
- Keeps up to 30 days of data by default

### Grafana
Grafana is the **visual layer** — it turns raw numbers into graphs you can understand:
- Pre-built dashboard with 19 panels (auto-provisioned, no setup needed)
- Shows uptime history, response times, SSL expiry countdowns, TLS versions
- Login with `admin` / your configured password

### Alertmanager
Alertmanager is the **notification router**. It:
- Receives alerts from Prometheus
- Groups related alerts (so you don't get 50 messages for the same problem)
- Sends to your chosen channels: Slack, Email, Discord, Teams, Telegram
- Handles "resolved" notifications when things recover

### Blackbox Exporter
Blackbox Exporter is the **active probe**. It:
- Makes real HTTP/HTTPS requests to your websites
- Checks SSL certificate validity and expiry
- Resolves DNS, connects via TCP, sends ICMP pings
- Reports timing for each phase: DNS lookup → TCP connect → TLS handshake → server response → transfer

---

## Prerequisites

Before installing, make sure you have:

| Requirement | Minimum version | How to check |
|-------------|----------------|--------------|
| Kubernetes cluster | 1.21+ | `kubectl version` |
| Helm | 3.8+ | `helm version` |
| A default StorageClass | Any | `kubectl get storageclass` |

**Don't have a cluster?** These work great for local testing:
- [Kind](https://kind.sigs.k8s.io/) — `kind create cluster`
- [Minikube](https://minikube.sigs.k8s.io/) — `minikube start`
- [k3s](https://k3s.io/) — single-command install for Linux servers

**For local testing without persistent storage**, use `examples/values-minimal.yaml` which disables PVCs.

---

## Quick Start

```bash
# 1. Create a namespace
kubectl create namespace monitoring

# 2. Install with defaults (monitors google.com + example.com)
helm install website-monitor . \
  --namespace monitoring \
  --set grafana.adminPassword=my-secure-password

# 3. Access Grafana
kubectl port-forward -n monitoring \
  svc/website-monitor-monitoring-pack-grafana 3000:3000

# 4. Open http://localhost:3000
#    Username: admin   Password: my-secure-password
```

That's it. The "Website Monitoring Dashboard" is already imported. Within 2 minutes you'll see live data.

---

## Installation

### Standalone Mode (default)

Standalone mode deploys all four components (Prometheus, Grafana, Alertmanager, Blackbox Exporter). This is the **recommended starting point** — no external dependencies needed.

#### Step 1 — Create your values file

Copy and edit `values.yaml`:

```bash
cp values.yaml my-values.yaml
```

Edit `my-values.yaml` — at minimum, replace the example targets with your own websites:

```yaml
targets:
  - name: My Website
    url: https://example.com
  - name: My API
    url: https://api.example.com

grafana:
  adminPassword: "choose-a-strong-password"
```

#### Step 2 — Install

```bash
helm install website-monitor . \
  --namespace monitoring \
  --create-namespace \
  -f my-values.yaml
```

#### Step 3 — Watch it come up

```bash
kubectl get pods -n monitoring -w
```

All pods should reach `Running` within 60–90 seconds.

#### Step 4 — Access Grafana

```bash
kubectl port-forward -n monitoring \
  svc/website-monitor-monitoring-pack-grafana 3000:3000
```

Open **http://localhost:3000** → log in → look for "Website Monitoring Dashboard".

---

### Integration with kube-prometheus-stack

If you already have [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) installed, you can plug Monitoring Pack into it instead of running a separate Prometheus/Grafana stack.

**What this mode deploys:**
- Blackbox Exporter (the probe)
- `ServiceMonitor` resources (so your existing Prometheus discovers the targets)
- `PrometheusRule` resource (so your existing Prometheus evaluates the alert rules)
- Grafana dashboard ConfigMap (auto-discovered by the Grafana sidecar)

**Step 1 — Find your kube-prometheus-stack release name:**

```bash
helm list -n monitoring
# Look for the kube-prometheus-stack release name, e.g., "kps"
```

**Step 2 — Configure values:**

```yaml
# Disable standalone components
prometheus:
  enabled: false
grafana:
  enabled: false
alertmanager:
  enabled: false

# Enable operator integration
serviceMonitor:
  enabled: true
  # Must match your Prometheus CR's serviceMonitorSelector
  labels:
    release: kps       # Replace with your kube-prometheus-stack release name

prometheusRule:
  enabled: true
  labels:
    release: kps       # Same label

# Auto-import dashboard into existing Grafana
grafana:
  enabled: false       # Don't deploy Grafana
  dashboardLabels:
    grafana_dashboard: "1"   # Grafana sidecar auto-discovers this

# Your targets
targets:
  - name: My Website
    url: https://example.com
  - name: My API
    url: https://api.example.com
```

**Step 3 — Install:**

```bash
helm install website-monitor . \
  --namespace monitoring \
  -f my-values.yaml
```

**Step 4 — Verify targets are discovered:**

```bash
# Open your existing Prometheus
kubectl port-forward -n monitoring svc/kps-prometheus 9090:9090
# Go to http://localhost:9090/targets and look for "blackbox-http" jobs
```

#### Using Probe CRD (recommended for prometheus-operator v0.47+)

An alternative to `serviceMonitor` is the `Probe` CRD — it's simpler and designed specifically for Blackbox-style probing:

```yaml
probe:
  enabled: true
  labels:
    release: kps
```

This creates `Probe` CRD resources instead of `ServiceMonitor` resources. The `Probe` CRD is more expressive and requires less relabeling configuration.

---

## Configuration Guide

### Adding Websites

All monitoring targets live under `targets` in `values.yaml`. Just add entries to the list:

```yaml
targets:
  # Basic HTTPS monitoring
  - name: My Homepage
    url: https://example.com

  # Monitor with a faster interval
  - name: Payment API
    url: https://payments.example.com
    interval: 30s      # Check every 30 seconds (default: 60s)

  # Self-signed certificate? Skip TLS verification
  - name: Internal Dashboard
    url: https://internal.company.local
    module: http_2xx_no_ssl_verify

  # HTTP (no SSL) — still monitored, just no SSL check
  - name: Legacy Service
    url: http://legacy.example.com
```

**Tip:** SSL certificates are automatically checked for all `https://` URLs. You don't need to add anything extra for SSL monitoring.

### Probe Types

The `module` field controls what kind of check is performed:

| Module | What it checks |
|--------|---------------|
| `http_2xx` | HTTP/HTTPS — expects a 2xx response code (default) |
| `http_post_2xx` | Same but sends POST requests |
| `http_2xx_no_ssl_verify` | HTTPS without TLS certificate verification |
| `ssl_expiry` | Applied automatically to all https:// targets |
| `tcp_connect` | Used for `tcpTargets` |
| `dns_check` | Used for `dnsTargets` |
| `icmp` | Used for `icmpTargets` (requires `blackboxExporter.privileged: true`) |

### TCP, DNS, and ICMP Targets

```yaml
# TCP — verify a port is open
tcpTargets:
  - name: PostgreSQL
    host: "db.example.com:5432"
  - name: Redis
    host: "cache.example.com:6379"
    interval: 30s

# DNS — verify a domain resolves
dnsTargets:
  - name: Main Domain
    host: "example.com"

# ICMP (Ping) — requires privileged: true!
icmpTargets:
  - name: Load Balancer
    host: "10.0.0.1"

blackboxExporter:
  privileged: true   # Required for ICMP
```

### Alert Thresholds

Fine-tune when alerts fire:

```yaml
alerts:
  ssl:
    warningDays: 30    # Warn when cert expires in < 30 days
    criticalDays: 7    # Critical when < 7 days

  responseTime:
    warning: 2.0       # Warn when response > 2 seconds
    critical: 5.0      # Critical when response > 5 seconds

  downFor: "1m"        # Must be down for 1 minute before alerting
                       # (prevents false alarms from brief hiccups)
```

### Environment and Team Labels

If you run this in multiple environments (dev, staging, production), use global labels to distinguish them. These labels appear on every Kubernetes resource and every Prometheus metric.

```yaml
global:
  environment: production   # dev, staging, production
  team: platform            # Which team owns this
  application: website-monitoring
```

This makes it easy to filter metrics in Grafana: `probe_success{environment="production"}`.

### Persistent Storage

By default, Monitoring Pack creates PersistentVolumeClaims to keep your data across pod restarts **and `helm upgrade`**:

```yaml
prometheus:
  persistence:
    enabled: true
    size: "20Gi"
    storageClass: ""   # Uses cluster default — or specify e.g. "fast-ssd"

grafana:
  persistence:
    enabled: true
    size: "5Gi"

alertmanager:
  persistence:
    enabled: true
    size: "2Gi"
```

What is preserved across upgrades:

| Component | What's kept |
|-----------|-------------|
| Prometheus | All metric history (up to 30 days) — historical anomalies are traceable |
| Grafana | Dashboard edits, annotations, user accounts |
| Alertmanager | Notification log, silences, inhibition state — resolved alerts send correctly |

**Kind / Minikube:** Works out of the box. Both ship with a `local-path` / `standard` StorageClass. No extra configuration needed.

**For environments with no StorageClass:**

```yaml
prometheus:
  persistence:
    enabled: false
grafana:
  persistence:
    enabled: false
alertmanager:
  persistence:
    enabled: false
```

**PVCs survive `helm uninstall`** — they're annotated with `helm.sh/resource-policy: keep` so you don't lose data accidentally. To delete them:

```bash
kubectl delete pvc -n monitoring -l app.kubernetes.io/instance=website-monitor
```

### Exposing Grafana

**Option 1: Port-forward (development)**
```bash
kubectl port-forward -n monitoring \
  svc/website-monitor-monitoring-pack-grafana 3000:3000
# Open http://localhost:3000
```

**Option 2: NodePort (simple clusters)**
```yaml
grafana:
  service:
    type: NodePort
    nodePort: 30300   # Access at http://<node-ip>:30300
```

**Option 3: Ingress with TLS (production)**
```yaml
grafana:
  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    host: grafana.example.com
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana.example.com
```

---

## Setting Up Notifications

### Slack

**Step 1:** Go to [https://api.slack.com/apps](https://api.slack.com/apps) → "Create New App" → "From scratch"

**Step 2:** In your app settings, click "Incoming Webhooks" → enable it → "Add New Webhook to Workspace"

**Step 3:** Choose the channel and copy the webhook URL

**Step 4:** Add to `values.yaml`:

```yaml
notifications:
  slack:
    enabled: true
    webhookUrl: "https://hooks.slack.com/services/T.../B.../..."
    channel: "#website-alerts"
    username: "Monitoring Pack"
```

**What you'll receive:**

```
🛰️ Monitoring Pack
🚨 Critical alert — immediate action required

🔴 [FIRING:1] WebsiteDown          ← red left sidebar
──────────────────────────────────────────────
🌐 Target    `https://example.com`
🔴 Severity  `CRITICAL`
📄 Summary   Website down: https://example.com
✏️  Detail    https://example.com has been unreachable for more than 1m
🕐 Since     `Jun 23, 2026 10:39 UTC`
🏷️  Job       `blackbox-http`

Monitoring Pack
```

Resolved alerts send a matching `✅ [RESOLVED]` message with a green sidebar.

> **Tip:** Never commit your webhook URL to git. Use a Kubernetes Secret or store it in your CI/CD secrets store.

---

### Email

Uses any SMTP server. Example with Gmail:

> **Gmail note:** You need an App Password, not your regular password.
> Google Account → Security → 2-Step Verification → App passwords

```yaml
notifications:
  email:
    enabled: true
    smarthost: "smtp.gmail.com:587"
    from: "alerts@example.com"
    to: "oncall@example.com"
    username: "alerts@example.com"
    password: "xxxx-xxxx-xxxx-xxxx"   # App password
    requireTLS: true
```

**Other SMTP providers:**

| Provider | smarthost |
|----------|-----------|
| Gmail | `smtp.gmail.com:587` |
| Outlook / Office 365 | `smtp.office365.com:587` |
| SendGrid | `smtp.sendgrid.net:587` |
| Amazon SES | `email-smtp.us-east-1.amazonaws.com:587` |

---

### Discord

Discord webhooks support a Slack-compatible format. Append `/slack` to your webhook URL.

**Step 1:** In Discord, go to your server → channel settings → Integrations → Webhooks → New Webhook → Copy URL

**Step 2:** Append `/slack` to the URL:
```
https://discord.com/api/webhooks/123456789/XXXXX/slack
                                                  ^^^^^^
```

**Step 3:**
```yaml
notifications:
  discord:
    enabled: true
    webhookUrl: "https://discord.com/api/webhooks/123456789/XXXXX/slack"
```

---

### Microsoft Teams

**Step 1:** In Teams, go to your channel → `···` menu → Connectors → "Incoming Webhook" → Configure

**Step 2:** Give it a name and copy the webhook URL

**Step 3:**
```yaml
notifications:
  teams:
    enabled: true
    webhookUrl: "https://outlook.office.com/webhook/..."
```

---

### Telegram

**Step 1:** Open Telegram and message `@BotFather` → `/newbot` → follow prompts → copy the **token**

**Step 2:** Add your bot to the group or channel where you want alerts

**Step 3:** Find your chat ID by visiting:
```
https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates
```
Look for `"chat":{"id":-1001234567890}` — the negative number is your chat ID.

**Step 4:**
```yaml
notifications:
  telegram:
    enabled: true
    botToken: "1234567890:AAFxxxxxxxxxx"
    chatId: "-1001234567890"   # Negative = group/channel
```

---

## Grafana Dashboard

The **Website Monitoring Dashboard** is automatically provisioned when Grafana starts. You don't need to import anything manually.

To access: open Grafana → Dashboards → "Website Monitoring Dashboard"

### Dashboard Sections

The dashboard is organized with the most critical information at the top:

| Section | What it shows |
|---------|-------------|
| **⚡ Live Health Status** | 6 stat cards with sparklines — **Sites Down first** (most critical), then Up, Availability %, Avg Response, SSL expiring, Total. Cards have colored backgrounds (red/green/orange). |
| **📊 Uptime History** | Full-width state timeline (10 rows tall) showing UP/DOWN history per target — instant visual pattern recognition |
| **🌐 Website Status** | Table with ✓ UP / ✗ DOWN color-coded cells, response time, HTTP status code, SSL days, TLS version |
| **🚀 Response Performance** | Line chart with fill gradient + HTTP phase breakdown (DNS / TCP / TLS / Server / Transfer) |
| **🔒 SSL Certificate Health** | Gauge per target showing days until expiry + trend chart |
| **🛡️ TLS & DNS Details** | TLS version table + DNS lookup time chart |
| **📈 Availability History (SLA)** | Probe success history + SLA table (1h / 6h / 24h / 7d / 30d) |
| **🔌 TCP / DNS / ICMP** | Collapsed row — expand to see TCP/DNS/ping probe results |

Dashboard auto-refreshes every **30 seconds**.

### Using the Dashboard with kube-prometheus-stack

If you're using an existing Grafana (from kube-prometheus-stack), add this to your values to auto-import the dashboard:

```yaml
grafana:
  dashboardLabels:
    grafana_dashboard: "1"   # Discovered by Grafana sidecar
```

Or import it manually: Dashboards → Import → paste the JSON from `dashboards/website-monitoring.json`.

---

## Alert Rules Reference

12 alert rules are included, organized into 4 groups:

### Website Availability

| Alert | When it fires | Severity |
|-------|-------------|---------|
| `WebsiteDown` | Target unreachable for **1 minute** | 🔴 Critical |
| `SlowResponseTimeWarning` | Response time > 2s for **3 minutes** | 🟡 Warning |
| `SlowResponseTimeCritical` | Response time > 5s for **1 minute** | 🔴 Critical |
| `UnexpectedHTTPStatus` | HTTP status ≥ 400 for **2 minutes** | 🟡 Warning (suppressed if `WebsiteDown` fires for same target) |

### SSL Certificates

| Alert | When it fires | Severity |
|-------|-------------|---------|
| `SSLCertExpiringSoon` | Certificate expires in < 30 days (for 30 min) | 🟡 Warning |
| `SSLCertExpiringCritical` | Certificate expires in < 7 days (for 30 min) | 🔴 Critical |
| `SSLCertExpired` | Certificate has expired | 🔴 Critical |
| `SSLProbeFailed` | Cannot establish TLS connection for 5 min | 🔴 Critical |

### TCP / DNS / ICMP

| Alert | When it fires | Severity |
|-------|-------------|---------|
| `TCPConnectionFailed` | Cannot connect via TCP for 2 minutes | 🔴 Critical |
| `DNSResolutionFailed` | DNS lookup fails for 2 minutes | 🔴 Critical |
| `ICMPProbeFailed` | Ping fails for 5 minutes | 🟡 Warning |

### Internal Health

| Alert | When it fires | Severity |
|-------|-------------|---------|
| `BlackboxExporterDown` | Blackbox Exporter unreachable for 2 minutes | 🔴 Critical |

All thresholds are configurable in `values.yaml` under the `alerts` key.

### Alert Timing

Understanding the delay between an outage and the Slack notification:

```
Endpoint goes down
  ↓  up to 60s   — wait for next Blackbox probe scrape
  ↓  up to 30s   — Prometheus evaluates alert rules every 30s
  ↓  1 minute    — for: 1m must expire (prevents false alarms from blips)
  ↓  ~10s        — Alertmanager group_wait before first notification
  = worst case ~2.5 minutes from outage to Slack message
```

**Key settings that affect timing:**

| Setting | Default | Effect |
|---------|---------|--------|
| `prometheus.scrapeInterval` | `60s` | How often Blackbox is polled |
| `prometheus.scrapeTimeout` | `20s` | Must be ≥ blackbox module timeout (15s) |
| `prometheus.evaluationInterval` | `30s` | How often alert rules are evaluated |
| `alerts.downFor` | `1m` | Consecutive failure window before alert fires |
| `alertmanager.groupWait` | `10s` | Delay before first notification in a new group |
| `alertmanager.repeatInterval` | `6h` | How often to re-notify if still firing |

> **Important:** `scrapeTimeout` must be **greater than** the blackbox module probe timeout (15s) and **less than** `scrapeInterval`. Violating this causes false-positive alerts.

### Alert Inhibition Rules

To avoid alert spam, firing `WebsiteDown` automatically suppresses these alerts for the **same target**:
- `UnexpectedHTTPStatus` — already implied by the site being down
- `SlowResponseTimeWarning` / `SlowResponseTimeCritical` — response time is meaningless when site is unreachable

If `BlackboxExporterDown` fires, **all** probe alerts are suppressed (they'd all be false positives).

---

## Multiple Environments

Run separate instances for dev, staging, and production using different namespaces and values files:

**`values-production.yaml`:**
```yaml
global:
  environment: production
  team: platform

targets:
  - name: Production Website
    url: https://example.com

alerts:
  ssl:
    warningDays: 45
    criticalDays: 14
  responseTime:
    warning: 1.0
    critical: 2.0
```

**`values-staging.yaml`:**
```yaml
global:
  environment: staging
  team: platform

targets:
  - name: Staging Website
    url: https://staging.example.com

alerts:
  ssl:
    warningDays: 14
    criticalDays: 3
  responseTime:
    warning: 3.0
    critical: 8.0

# Smaller resources for staging
prometheus:
  resources:
    requests:
      memory: "128Mi"
      cpu: "50m"
```

**Install both:**
```bash
helm install monitor-prod . \
  --namespace monitoring-prod \
  --create-namespace \
  -f values-production.yaml

helm install monitor-staging . \
  --namespace monitoring-staging \
  --create-namespace \
  -f values-staging.yaml
```

Prometheus metrics from each instance are labeled with `environment="production"` or `environment="staging"`, so you can filter in dashboards and alerts.

---

## Upgrade

After editing `values.yaml`, apply changes with:

```bash
helm upgrade website-monitor . --namespace monitoring --atomic --timeout 5m
```

> **Do not pass `--set persistence.enabled=false` during upgrades.** Doing so wipes all historical metric data and Alertmanager state on pod restart.

Adding or removing targets takes effect within one scrape interval (~60 seconds) after the Prometheus pod restarts. All historical data before the upgrade remains intact.

**Check what will change before applying:**
```bash
helm diff upgrade website-monitor . -f my-values.yaml
# Requires: helm plugin install https://github.com/databus23/helm-diff
```

**What survives an upgrade:**
- All Prometheus metric history (PVC persisted)
- Grafana dashboards and user sessions (PVC persisted)
- Alertmanager silences and notification log (PVC persisted)
- Any in-flight alert state is re-evaluated automatically after Prometheus restarts

---

## Uninstall

```bash
helm uninstall website-monitor --namespace monitoring
```

This removes all resources **except PVCs** (by design — your data is safe).

To also delete the data:
```bash
kubectl delete pvc -n monitoring \
  -l app.kubernetes.io/instance=website-monitor
```

To delete the namespace entirely:
```bash
kubectl delete namespace monitoring
```

---

## Troubleshooting

### Pods are not starting

```bash
# Check pod status
kubectl get pods -n monitoring

# See why a pod failed
kubectl describe pod -n monitoring <pod-name>

# View logs
kubectl logs -n monitoring <pod-name>
```

Common causes:
- **PVC Pending**: No StorageClass available — set `persistence.enabled: false` for testing, or set `storageClass` to a valid class (`kubectl get storageclass`)
- **OOMKilled**: Increase memory limits in values.yaml
- **ImagePullBackOff**: No internet access from cluster — ensure nodes can reach Docker Hub

---

### Grafana is empty / no data

```bash
# Port-forward Prometheus and check targets
kubectl port-forward -n monitoring \
  svc/website-monitor-monitoring-pack-prometheus 9090:9090
# Open http://localhost:9090/targets
# All targets should be "UP" in green
```

In Grafana, go to **Configuration → Data Sources → Prometheus → Test**. If it fails, check that Prometheus is running and the service URL is correct.

---

### Test a probe manually

```bash
kubectl port-forward -n monitoring \
  svc/website-monitor-monitoring-pack-blackbox 9115:9115

# Test HTTP probe
curl "http://localhost:9115/probe?target=https://example.com&module=http_2xx"

# Test SSL expiry
curl "http://localhost:9115/probe?target=https://example.com&module=ssl_expiry"

# Test TCP
curl "http://localhost:9115/probe?target=db.example.com:5432&module=tcp_connect"
```

A successful probe shows `probe_success 1` at the bottom of the response.

---

### Alerts are not firing

```bash
# 1. Check alert rules are loaded and evaluate correctly
kubectl port-forward -n monitoring \
  svc/website-monitor-monitoring-pack-prometheus 9090:9090
# Open http://localhost:9090/alerts
# - "Inactive" = condition not currently true (site is up)
# - "Pending"  = condition true but for: timer not expired yet
# - "Firing"   = alert is active, should be in Alertmanager
```

```bash
# 2. Check Alertmanager received the alert and config is valid
kubectl port-forward -n monitoring \
  svc/website-monitor-monitoring-pack-alertmanager 9093:9093
# Open http://localhost:9093/#/alerts  — shows active alerts
# Open http://localhost:9093/#/status  — shows config + any errors
```

```bash
# 3. Verify the notification channel is enabled in values.yaml
#    notifications.slack.enabled must be true (not false)
helm get values website-monitor -n monitoring | grep -A5 slack
```

```bash
# 4. Test the Slack webhook directly
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test from Monitoring Pack"}' \
  YOUR_WEBHOOK_URL
```

**Common causes of missing alerts:**
- Notification channel `enabled: false` in values.yaml
- `scrapeTimeout` shorter than the blackbox module timeout → false probe failures that don't reach Alertmanager
- Alert in "Pending" state — wait for `alerts.downFor` duration to pass
- `WebsiteDown` inhibiting `UnexpectedHTTPStatus` for the same target (by design)

---

### ServiceMonitor targets not discovered (kube-prometheus-stack mode)

Check that the labels on your `ServiceMonitor` match the `serviceMonitorSelector` in your Prometheus CR:

```bash
# Find what labels your Prometheus requires
kubectl get prometheus -n monitoring -o jsonpath='{.items[0].spec.serviceMonitorSelector}'
# Output example: {"matchLabels":{"release":"kps"}}

# Make sure your serviceMonitor.labels matches:
# serviceMonitor:
#   labels:
#     release: kps
```

---

## FAQ

**Q: Will this slow down my website?**
A: No. Blackbox Exporter sends one HTTP GET request per target per minute. This is indistinguishable from a normal visitor.

**Q: Does this work with HTTP (non-HTTPS) sites?**
A: Yes. Set `url: http://example.com`. SSL certificate checks are skipped for non-HTTPS targets automatically.

**Q: Can I monitor sites behind authentication?**
A: Yes, use a custom module in `blackboxExporter`'s configmap with HTTP headers or basic auth configured.

**Q: How much disk space does it use?**
A: With default settings, Prometheus stores 30 days of data at ~60-second resolution. For 10 targets, expect ~500MB–2GB. The PVC is set to 20Gi by default.

**Q: Can I add the Grafana dashboard to my existing Grafana?**
A: Yes! Import the JSON from `dashboards/website-monitoring.json` via Grafana → Dashboards → Import. Make sure a Prometheus datasource named "Prometheus" exists.

**Q: What's the difference between `serviceMonitor`, `probe`, and `prometheusRule`?**
A: These are Kubernetes CRDs provided by Prometheus Operator:
- `ServiceMonitor` — tells Prometheus which services to scrape (and how)
- `Probe` — tells Prometheus which external URLs to probe through a Blackbox Exporter
- `PrometheusRule` — defines alert rules as Kubernetes resources instead of config files

All three are only needed when using an existing Prometheus Operator (kube-prometheus-stack). In standalone mode, they're not used.

**Q: My SSL certificate expires in 25 days but I'm not getting a warning alert.**
A: Alerts for SSL have a `30m` "for" duration — the condition must be true for 30 minutes before the alert fires. Also check that your alert threshold is `warningDays: 30` (not lower). Because the SSL probe runs every 5 minutes, the alert will fire within ~35 minutes of being detected.

**Q: Can I run multiple instances of Monitoring Pack?**
A: Yes — use different Helm release names and namespaces (see [Multiple Environments](#multiple-environments)).

**Q: How do I suppress alerts for a planned maintenance window?**
A: Use Alertmanager silences: open Alertmanager (port 9093) → Silences → New Silence. Set duration and matchers (e.g., `instance="https://example.com"`).

---

## Project Structure

```
monitoring-pack/
├── Chart.yaml                          # Chart metadata
├── values.yaml                         # All configuration (edit this)
├── README.md                           # This file
│
├── templates/
│   ├── _helpers.tpl                    # Reusable template helpers
│   ├── _alert_rules.tpl                # Shared alert rules (used by both
│   │                                   #   configmap and PrometheusRule CRD)
│   ├── NOTES.txt                       # Post-install message
│   ├── serviceaccount.yaml             # RBAC: ServiceAccount
│   ├── clusterrole.yaml                # RBAC: ClusterRole + Binding
│   ├── servicemonitor.yaml             # Prometheus Operator: ServiceMonitor
│   ├── prometheusrule.yaml             # Prometheus Operator: PrometheusRule
│   ├── probe.yaml                      # Prometheus Operator: Probe CRD
│   │
│   ├── prometheus/
│   │   ├── configmap.yaml              # prometheus.yml + alert rules
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── pvc.yaml
│   │
│   ├── grafana/
│   │   ├── configmap-datasources.yaml  # Auto-provisions Prometheus datasource
│   │   ├── configmap-dashboards.yaml   # Tells Grafana where to find dashboards
│   │   ├── configmap-dashboard-json.yaml  # The actual dashboard JSON
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   ├── secret.yaml
│   │   └── pvc.yaml
│   │
│   ├── alertmanager/
│   │   ├── configmap.yaml              # alertmanager.yml with routing + receivers
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── pvc.yaml
│   │
│   └── blackbox/
│       ├── configmap.yaml              # blackbox.yml with probe modules
│       ├── deployment.yaml
│       └── service.yaml
│
├── files/
│   └── dashboards/
│       └── website-monitoring.json     # Source dashboard JSON (loaded via Files.Get)
│
├── dashboards/
│   └── website-monitoring.json         # Reference copy — import into any Grafana
│
├── alert-rules/
│   └── website-alerts.yaml             # Reference copy of alert rules
│
├── examples/
│   ├── values-minimal.yaml             # Minimal setup (no persistence)
│   ├── values-production.yaml          # Full production config
│   └── values-slack-notifications.yaml # Multi-channel notification example
│
├── .github/
│   └── workflows/
│       └── ci.yml                      # GitHub Actions CI pipeline
│
├── values.schema.json                  # JSON Schema validation for values
├── LICENSE                             # MIT license
├── CHANGELOG.md                        # Version history
├── CONTRIBUTING.md                     # Contribution guide
├── SECURITY.md                         # Security policy
└── CODE_OF_CONDUCT.md                  # Community standards
```

---

## Security Hardening

### Use an existing Secret for Grafana credentials

Avoid storing passwords in `values.yaml`. Create a Kubernetes Secret first:

```bash
kubectl create secret generic my-grafana-secret \
  --namespace monitoring \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=my-secure-password
```

Then reference it in values:

```yaml
grafana:
  existingSecret: my-grafana-secret
```

### Enable NetworkPolicy

Restricts which pods can communicate with each component:

```yaml
networkPolicy:
  enabled: true
```

Requires a CNI plugin that enforces NetworkPolicy (Calico, Cilium, Weave Net).

### Enable PodDisruptionBudgets

Prevents all pods from being evicted simultaneously during cluster maintenance:

```yaml
podDisruptionBudget:
  enabled: true
  maxUnavailable: 1   # Safe for single-replica deployments
```

---

## Dashboard Screenshots

> **Grafana Website Monitoring Dashboard**

```
┌─────────────────────────────────────────────────────────────────┐
│ Monitored Sites: 5  │  Up: 4  │  Down: 1  │  SSL Expiring: 1   │
├─────────────────────────────────────────────────────────────────┤
│ STATUS TIMELINE                                                  │
│ google.com   ████████████████████████████████░░████████  UP     │
│ github.com   ████████████████████████████████████████   UP      │
│ example.com  ██░░░░░░░░████████████████████████████████ WARN    │
├──────────────────────┬──────────────────────────────────────────┤
│ RESPONSE TIME (ms)   │ SSL CERTIFICATE EXPIRY                   │
│ 200ms ─────────────  │ google.com    ████████████████  45 days  │
│ 150ms      ____      │ github.com    ██████████████    38 days  │
│ 100ms _____    ───   │ example.com   ██              6 days ⚠️  │
└──────────────────────┴──────────────────────────────────────────┘
```

*Live screenshots: [add after first deployment]*

---

## License

MIT — see [LICENSE](LICENSE) for the full text.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for a full contribution guide including setup, testing, and PR requirements.

In short:
1. Fork and create a branch
2. Run `helm lint --strict .` and `helm template .` before submitting
3. Open a pull request with a description of what changed and why

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full version history.

**Latest: v1.1.0** — Rich Slack alert format (colored sidebar, emoji, resolved notifications), faster alert delivery (~2.5 min worst case), persistence enabled by default, 10 bug fixes including scrape timeout mismatch and alert inhibition rules.

**v1.0.0** — Initial release with Prometheus, Grafana, Alertmanager, Blackbox Exporter, 12 alert rules, pre-built dashboard, 5 notification channels, and Prometheus Operator CRD integration.
