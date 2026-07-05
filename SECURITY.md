# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 1.x     | ✓ Yes     |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

To report a vulnerability, email **security@example.com** with the subject line:
`[SECURITY] monitoring-pack — <brief description>`

Please include:
1. The version of the chart affected
2. A description of the vulnerability
3. Steps to reproduce the issue
4. The potential impact of the vulnerability

You should receive a response within **72 hours**. If you do not, please follow up to ensure we received your message.

We will:
- Acknowledge your report within 72 hours
- Investigate and confirm the issue
- Work on a fix and release it as a patch version
- Credit you in the release notes (unless you prefer to remain anonymous)

## Security Best Practices When Deploying

### Credentials
- **Never** commit `values.yaml` files containing real passwords to version control
- Use `grafana.existingSecret` to reference a Kubernetes Secret managed by your secrets operator (e.g., [External Secrets Operator](https://external-secrets.io/), [Sealed Secrets](https://sealed-secrets.netlify.app/))
- Rotate `grafana.adminPassword` from the default `monitoring-pack-admin` before production use
- Store notification webhook URLs (Slack, Teams, Telegram) in Kubernetes Secrets

### Network Access
- Enable `networkPolicy.enabled: true` to restrict which pods can reach each component
- Avoid setting Prometheus or Alertmanager `service.type: LoadBalancer` — they have no built-in authentication
- Use Ingress with TLS and authentication middleware (e.g., nginx `auth-basic` or OAuth2-proxy) for any public-facing endpoints

### RBAC
- The chart creates a dedicated ServiceAccount with **no Kubernetes API permissions by default** — probing external websites/SSL/TCP/DNS needs none
- Optional in-cluster pod discovery (`podMonitoring.enabled: true`) grants a namespace-scoped `Role` by default; only `podMonitoring.namespaces: ["*"]` escalates to a cluster-wide `ClusterRole` with node-level access — see `templates/rbac.yaml` and the README's "RBAC is least-privilege by default" section

### Updates
- Monitor the component image tags in `values.yaml` and update them regularly
- Subscribe to security advisories for Prometheus, Grafana, Alertmanager, and Blackbox Exporter
