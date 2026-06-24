# Contributing to Monitoring Pack

Thank you for considering contributing! This guide covers everything you need to know.

## Table of Contents

- [Ways to Contribute](#ways-to-contribute)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting a PR](#submitting-a-pr)
- [Release Process](#release-process)

---

## Ways to Contribute

- **Report bugs** — open a GitHub issue with the bug report template
- **Suggest features** — open a GitHub issue with the feature request template
- **Fix bugs** — pick an issue labelled `good first issue` or `bug`
- **Add features** — discuss in an issue before writing code
- **Improve docs** — fix typos, clarify confusing sections, add examples

---

## Development Setup

### Prerequisites

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| Helm | v3.12 | Chart development and linting |
| kubectl | v1.25 | Kubernetes interaction |
| kind | v0.20 | Local Kubernetes cluster |
| yamllint | 1.35 | YAML linting |
| Python | 3.8 | Required by yamllint |

### Install tools

```bash
# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# kind
go install sigs.k8s.io/kind@latest
# or: brew install kind

# yamllint
pip install yamllint
```

### Fork and clone

```bash
git clone https://github.com/YOUR_USERNAME/monitoring-pack.git
cd monitoring-pack
```

---

## Making Changes

### Chart structure

```
monitoring-pack/
├── Chart.yaml              — chart metadata
├── values.yaml             — default values (the only file users edit)
├── values.schema.json      — JSON Schema validation for values
├── templates/
│   ├── _helpers.tpl        — shared named templates
│   ├── _alert_rules.tpl    — shared alert rule groups
│   ├── NOTES.txt           — post-install output
│   ├── prometheus/         — Prometheus resources
│   ├── grafana/            — Grafana resources
│   ├── alertmanager/       — Alertmanager resources
│   ├── blackbox/           — Blackbox Exporter resources
│   └── tests/              — Helm test pods
├── files/
│   └── dashboards/         — Grafana dashboard JSON
└── examples/               — Example values files
```

### Key conventions

1. **All configuration lives in `values.yaml`** — never hardcode values in templates
2. **Every new resource must respect `enabled` flags** — wrap in `{{- if .Values.component.enabled }}`
3. **Every resource must include standard labels** — use `{{- include "monitoring-pack.labels" . | nindent 4 }}`
4. **Alert rules are defined once** — in `templates/_alert_rules.tpl`, shared between the ConfigMap and PrometheusRule CRD
5. **Dashboard JSON lives outside `templates/`** — in `files/dashboards/` to prevent Helm from parsing Grafana template expressions
6. **Security by default** — new containers must have `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`, `readOnlyRootFilesystem: true`

### Adding a new monitoring target type

1. Add target list to `values.yaml` (e.g., `mongoTargets`)
2. Add a scrape job in `templates/prometheus/configmap.yaml`
3. Add an alert rule group in `templates/_alert_rules.tpl`
4. Add a ServiceMonitor endpoint in `templates/servicemonitor.yaml`
5. Update the dashboard JSON in `files/dashboards/website-monitoring.json`
6. Update the Grafana dashboard ConfigMap checksum annotation
7. Update README with documentation

### Adding a notification channel

1. Add config block to `values.yaml` under `notifications`
2. Add a named template helper in `templates/_helpers.tpl`
3. Include the new helper in `templates/alertmanager/configmap.yaml`
4. Update `templates/NOTES.txt` notification status section
5. Add setup instructions to README

---

## Testing

### Before every PR

```bash
# 1. Lint YAML files
yamllint -c .yamllint.yml values.yaml Chart.yaml .github/

# 2. Helm strict lint
helm lint --strict .

# 3. Render all configuration combinations
helm template website-monitor . > /dev/null
helm template website-monitor . \
  --set prometheus.enabled=false \
  --set serviceMonitor.enabled=true \
  --set prometheusRule.enabled=true > /dev/null

# 4. Test with a local kind cluster
kind create cluster --name monitoring-test
helm install website-monitor . \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.persistence.enabled=false \
  --set grafana.persistence.enabled=false \
  --set alertmanager.persistence.enabled=false \
  --wait --timeout 5m

helm test website-monitor --namespace monitoring --logs

# 5. Cleanup
kind delete cluster --name monitoring-test
```

### Adding tests

Helm tests live in `templates/tests/test-connectivity.yaml`. Add new assertions to the shell script in that pod. Keep the image as `curlimages/curl:8.5.0` for consistency.

---

## Submitting a PR

1. **Create a branch** from `main`:
   ```bash
   git checkout -b feat/my-feature
   ```

2. **Make your changes** following the conventions above

3. **Run all tests** (see Testing section)

4. **Commit** with a clear message:
   ```
   feat: add Redis TCP probe support
   fix: prevent SSL alert from firing on non-HTTPS targets
   docs: clarify multi-environment setup
   ```

5. **Push and open a PR** — fill in the PR template fully

6. **CI must pass** — the GitHub Actions pipeline runs on every PR

### PR checklist

- [ ] `helm lint --strict .` passes with 0 errors
- [ ] `helm template .` renders without errors in all modes
- [ ] New values are documented in `values.yaml` with comments
- [ ] New values are added to `values.schema.json`
- [ ] README is updated if behaviour changes
- [ ] CHANGELOG.md is updated

---

## Release Process

Releases are tagged by maintainers using `v<major>.<minor>.<patch>` (e.g., `v1.1.0`).

1. Update `version` in `Chart.yaml`
2. Add entry to `CHANGELOG.md`
3. Push to `main` — CI runs automatically
4. Create a GitHub Release with the tag `v<version>`

---

Thank you for contributing!
