# EIRA Cytology Capture

## Scope

**In:** one EIRA form (`citologia_eira_v1.xlsx`), offline capture on 1–2 Android tablets (ODK Collect), sync to one ODK Central server, CSV export.

**Out (post-MVP):** Valkey, dashboards/Power BI, `central-sync` replication, multi-clinic roles, Enketo web entry, any custom application code.

> The Enketo container is still part of the official Central stack and keeps running. It just isn't used for data entry in the MVP.

## Two ways to build the server

Every phase below says what changes between these two paths.

| | **Path A: existing server (public IP + SSH key + sudo user)** | **Path B: cloud API token (DigitalOcean / AWS / GCP)** |
|---|---|---|
| Who creates the VM | You (clinic IT or the provider console) | Devin, using the provider's official CLI (`doctl`, `aws`, `gcloud`) |
| What you give Devin | Public IPv4, SSH private key, sudo username, domain name | Scoped API token/credentials, region, domain name, SSH public key |
| Firewall | You open 80/443 (and 22, ideally limited to your IPs) | Devin creates a cloud firewall / security group |
| Static IP | Must already be static | Devin reserves one (DO Reserved IP / AWS Elastic IP / GCP static external IP) |
| Off-server backups | You supply a destination (S3-compatible bucket or another host) | Devin creates a bucket in the same provider (DO Spaces / S3 / GCS) |
| Teardown | Manual | One documented CLI step |
| Convergence | From Phase 2, step "Install Docker", **both paths are identical**: Devin connects over SSH as a sudo user. | |

### Server minimums (both paths)

- Ubuntu 22.04 or 24.04 LTS, x86_64
- 2 vCPU, 2 GB RAM (plus 2 GB swap), 25 GB+ disk. Central runs on 1 GB, but builds and Enketo are tight.
- Public IPv4, inbound TCP 80 and 443 open (Let's Encrypt HTTP-01 needs port 80)
- A DNS `A` record pointing to that IP. If there's no domain yet, use `<ip-with-dashes>.sslip.io` for the MVP (for example `203-0-113-10.sslip.io`).

A clinic PC is only viable for Path A if it has a public static IP and ports 80/443 forwarded. Otherwise use a small VPS. Without a reachable public HTTPS endpoint, tablets can't sync from outside the clinic and Let's Encrypt can't issue a certificate.

### Credentials per path (never committed: stored as Devin secrets)

**Path A**
- `SERVER_IP`: public IPv4
- `SSH_USER`: user with passwordless sudo (or tell Devin the sudo password via a secret)
- `SSH_PRIVATE_KEY`: key authorised in `~/.ssh/authorized_keys` of that user
- `CENTRAL_DOMAIN`, `ADMIN_EMAIL`
- Backup target: S3-compatible bucket + keys, or `user@host:/path` reachable via SSH

**Path B: DigitalOcean**
- `DIGITALOCEAN_TOKEN`: custom-scoped token. Scopes: droplet, ssh_key, firewall, reserved_ip, (domain if DNS is on DO), Spaces keys for backups.

**Path B: AWS**
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` for an IAM user limited to EC2 (instances, key pairs, security groups, Elastic IPs) and one S3 bucket; `AWS_REGION`.

**Path B: GCP**
- Service-account JSON key with `roles/compute.admin` (or narrower: instanceAdmin + securityAdmin + networkAdmin) and `roles/storage.admin` scoped to one bucket; `GCP_PROJECT`, `GCP_ZONE`.

After provisioning, Path B tokens can be revoked or reduced to backup-bucket access only.

---

## Phase 0: Prep and decisions

**Goal:** remove blockers before any code.

| Step | Path A | Path B |
|---|---|---|
| Get the complete EIRA questionnaire into `xlsform/eira_questionnaire.csv` (template provided) | same | same |
| Choose hosting | Confirm the server meets the minimums, has a static IP, and 80/443 are reachable | Pick provider + region (closest to the clinic) and size (DO `s-2vcpu-2gb`, AWS `t3.small`, GCP `e2-small`) |
| Domain | Point `A` record to the existing IP, or use sslip.io | Domain decided now; the `A` record is created after the static IP exists (Phase 2) |
| Access | Verify `ssh -i key user@ip sudo -n true` works | Create a scoped token; store it as a Devin secret |
| Backup destination | Decide where `pg_dump` files go off-server | Bucket in the same provider (created in Phase 2) |
| Tablets + Wi-Fi/hotspot | same | same |
| Repo structure `/xlsform`, `/deploy`, `/docs`, `/tests` | same | same |

**Done when:** the full question list is in the repo and `docs/DECISIONS.md` has the hosting path, provider/server, domain, and backup destination filled in.

## Phase 1: Build the XLSForm

**Goal:** a valid `xlsform/citologia_eira_v1.xlsx`. **No difference between paths** (no server needed).

- Sheets `survey`, `choices`, `settings`.
- Groups: Patient Data, History, Examination, Result (`begin_group` / `end_group`).
- Choice lists: `yes_no`, `states`, `affiliations`, `bethesda`, and others found in the questionnaire.
- `settings`: `form_title`, `form_id` = `citologia_eira`, `version` = date-based, e.g. `2026112101`.
- Validate with `pyxform` (`xls2xform`); preview in ODK Web Forms / getodk.org validator.
- Test list in `tests/` (valid, invalid such as age 20 or 60, skip-logic cases).

**Done when:** `xls2xform` converts with no errors and every constraint/skip rule behaves as designed in a preview.

## Phase 2: Deploy ODK Central

**Goal:** a running, backed-up server.

| Step | Path A | Path B |
|---|---|---|
| Provision host | Already exists. Devin checks OS, RAM, disk, ports | Devin creates VM + SSH key + firewall (22 limited, 80, 443) + static IP via CLI; commands saved in `deploy/` |
| DNS | Already pointing | Create/update `A` record to the new static IP; wait for propagation |
| Harden | Non-root sudo user, key-only SSH, `ufw` allow 22/80/443, unattended-upgrades, swap | same (on top of cloud firewall) |
| Install Docker Engine + Compose plugin (official apt repo) | same | same |
| Clone `getodk/central` (latest release tag), `git submodule update --init`, copy `.env.template` → `.env` (`DOMAIN`, `SYSADMIN_EMAIL`, `SSL_TYPE=letsencrypt`) | same | same |
| `docker compose build && docker compose up -d`; check `docker compose ps` all healthy | same | same |
| Create admin (`odk-cmd user-create` + `user-promote`), project "EIRA", enable project-managed encryption (see open question 3), upload form | same | same |
| PostgreSQL not exposed: no published 5432, verify with `ss -tlnp` on host and an external port scan | same | same + verify the cloud firewall has no 5432 rule |
| Daily `pg_dump` (cron on host) copied off-server | To the destination from Phase 0 (`rclone`/`aws s3 cp`/`rsync`) | To the provider bucket created now (Spaces / S3 / GCS), lifecycle rule e.g. 30 days |
| Restore test | Restore latest dump into a scratch Postgres container, check row counts | same |

**Done when:** HTTPS login works, the form is visible, Postgres isn't reachable from outside, and a backup/restore test passes.

## Phase 3: Configure tablets and users

**Goal:** tablets ready for the field. **No difference between paths**: only the server URL (`https://<CENTRAL_DOMAIN>`) matters.

- Install ODK Collect (Play Store).
- In Central: one app user per tablet/clinician, assigned to project EIRA with access to the form.
- Scan the app user's QR code in Collect.
- Download the form while online.
- Collect settings: auto-send **Wi-Fi only** (or off for manual send), keep finalized forms after sending (decide), constraint processing on finalize.

**Done when:** a tablet shows the EIRA form and can open it in airplane mode.

## Phase 4: Offline end-to-end test

**Goal:** prove the core promise. **No difference between paths.**

- Airplane mode, fill 5–10 test records (valid, invalid, skip-logic cases from `tests/`).
- Reconnect to Wi-Fi and send.

**Done when (proposed):** every record finalized offline appears in Central exactly once, with values matching the test sheet.

## Phase 5: Data export and review

**Goal:** the data is usable. **No difference between paths.**

- Export CSV from Central (with the encryption passphrase if encryption is on), open in Excel.
- Check column names, select values (`asc_us`, `hsil`, …), and dates.
- Test the OData endpoint from Excel / Power Query (see open question 3).

**Done when:** a non-technical user can get a CSV of all records following `docs/`.

## Phase 6: Pilot and handoff

| Step | Path A | Path B |
|---|---|---|
| Pilot: 1 clinician, ~20 records; collect feedback | same | same |
| Fix form, bump `version`, re-upload, confirm tablets get the update | same | same |
| Docs: deploy, back up/restore, add a user, update the form, troubleshoot sync | Deploy doc starts at "SSH in" | Deploy doc includes the provider CLI provisioning, cost estimate, and teardown |

**Done when:** pilot finished, v2 deployed cleanly, docs in the repo.

---

## Working rules

- One phase at a time; stop for review after each.
- Nothing outside MVP scope (no Valkey, no custom code beyond deploy/backup shell commands).
- Secrets (`.env`, keys, tokens, backup credentials, encryption passphrase) never go in git.
- Each phase report: what was done, how it was tested, open questions.

## Open questions

1. **Full EIRA questionnaire.** Only a ~10-question fragment exists. Phase 1 can't finish without all questions, options, and validations.
2. **Hosting path (A or B), provider, domain, backup destination.** Record in `docs/DECISIONS.md`.
3. **Encryption vs OData.** Phase 3 asks for encryption on, Phase 5 asks for OData. In ODK Central, encrypted submissions are **not available via OData** (CSV export still works with the passphrase). Choose: (a) encryption on and drop OData from the MVP, or (b) no form encryption (rely on HTTPS + disk/backup encryption) and keep OData.
4. **Age rule.** "Invalid: age 20 or 60" implies a valid range like 25–59 or 21–59. Exact bounds must come from the questionnaire.
5. **Phase 4 "Done when"** was cut off in the plan; proposed wording is above.
