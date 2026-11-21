# Decisions (Phase 0)

Fill in and commit. No secrets here: credentials go in Devin secrets / local `.env` only.

| Decision | Value | Status |
|---|---|---|
| Deploy path | A (existing server via SSH): runbook in `deploy/path-a/` | decided |
| Provider (Path B) or host description (Path A) | | **pending** |
| Region / location | | **pending** |
| Server size | 2 vCPU / 2 GB RAM / 25 GB+ | proposed |
| OS | Ubuntu 24.04 LTS | proposed |
| Domain for Central | e.g. `central.example.org` or `<ip>.sslip.io` | **pending** |
| Admin email (Let's Encrypt + Central sysadmin) | | **pending** |
| Off-server backup destination | | **pending** |
| Backup retention | 30 days | proposed |
| Form encryption vs OData | see MVP_SCOPE.md open question 3 | **pending** |
| Collect send policy | Auto-send on Wi-Fi only | proposed |
| Tablets (model, Android version, count) | | **pending** |
| Test network | Clinic Wi-Fi / phone hotspot | **pending** |
