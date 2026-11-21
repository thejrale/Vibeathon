# Path A: deploy ODK Central to an existing server

Runs from your laptop (or Devin's VM) over SSH. All server work happens with `sudo` on the target.

No server yet? Follow [CREATE_VPS.md](CREATE_VPS.md) first.

## Requirements

- Ubuntu 22.04/24.04 x86_64, 2 vCPU, 2 GB RAM, 20 GB+ free disk, static public IPv4
- Inbound TCP 22, 80, 443 open at any upstream firewall/router
- A user with sudo whose `authorized_keys` contains your SSH public key
- `CENTRAL_DOMAIN` has an `A` record pointing to the server IP (or use `<ip-with-dashes>.sslip.io`)

## Configure

```bash
cp deploy/env.example deploy/.env   # git-ignored
# fill CENTRAL_DOMAIN, ADMIN_EMAIL, SERVER_IP, SSH_USER, SSH_KEY_PATH
# if sudo needs a password, export SUDO_PASSWORD in your shell (don't put it in files)
```

## Steps

| # | Command | What it does | Check |
|---|---|---|---|
| 1 | `./run.sh preflight` | SSH + sudo work, OS/RAM/disk, ports 80/443 free, DNS points at the IP | all `OK`, no `FAIL` |
| 2 | `./run.sh harden` | apt upgrade, unattended-upgrades, `ufw` 22/80/443, key-only SSH, 2 GB swap | you can still SSH in |
| 3 | `./run.sh docker` | Docker Engine + Compose plugin (official repo) | `docker compose version` |
| 4 | `./run.sh central` | `getodk/central` at `CENTRAL_VERSION` in `/opt/central`, `.env` with Let's Encrypt, build + start | nginx `healthy` |
| 5 | `./run.sh verify` | every container running/healthy, no Postgres port on host, 5432 closed from outside, HTTPS cert valid | all `OK` |
| 6 | Create admin (below) | first web user | log in at `https://CENTRAL_DOMAIN` |
| 7 | Project "EIRA" in the web UI | | project listed |
| 8 | `./run.sh backup-setup` | daily `pg_dump` at 02:30 to `/var/backups/odk`, copied with `rclone` to `BACKUP_TARGET` | first dump file listed |
| 9 | `./run.sh restore-test` | restores latest dump into a throwaway Postgres 14 and compares row counts | `OK restore matches live` |

`./run.sh all` runs steps 1–5. Every step is safe to re-run. For step 6 you can also use `./run.sh add-central-user <email> admin` (below).

### Create the admin (step 6)

```bash
ssh -t $SSH_USER@$SERVER_IP
cd /opt/central
sudo docker compose exec service odk-cmd --email you@example.org user-create   # prompts for password
sudo docker compose exec service odk-cmd --email you@example.org user-promote
```

### Share access with other people

Each person gets their own login. Temporary passwords are printed once; send them privately (not by email in plain text with the username).

**Central web login** (Dra. Rojas, clinicians, data managers):

```bash
./run.sh add-central-user thejrale@gmail.com admin   # Administrator: manages everything
./run.sh add-central-user nerd@devin.mx              # plain web user, no project access yet
```

Then, in the web UI as an Administrator: Projects → EIRA → Project Roles → add the plain user as **Project Manager** or **Data Collector**. Each person changes the temporary password under their name (top right) → Edit profile.

**Server (SSH) login** (technical people only). SSH is key-only, so each person sends you their **public** key (made with `ssh-keygen -t ed25519`, file `~/.ssh/id_ed25519.pub`):

```bash
./run.sh add-ssh-user ana ana_id_ed25519.pub          # can log in, no admin rights
./run.sh add-ssh-user ana ana_id_ed25519.pub --sudo   # can also administer the server
```

With `--sudo` a temporary sudo password is printed; the person must choose a new one the first time they connect with `ssh ana@<IP>`. Re-running adds another key to the same user.

Tablets don't use either of these: they use Central **App Users** + QR code (Phase 3).

### Off-server backups (step 8)

On the server run `sudo rclone config` once and create a remote (S3-compatible bucket, Google Drive, SFTP to another host, …). Then set `BACKUP_TARGET=<remote>:<path>` in `deploy/.env` and run `./run.sh backup-setup`. With `BACKUP_TARGET` empty, dumps stay only on the server (not acceptable for Phase 2 "done").

## Notes

- Only nginx publishes ports (80/443). Postgres stays on the internal Docker network.
- Docker-published ports bypass `ufw`; that's fine here because only 80/443 are published.
- Upgrading Central later: bump `CENTRAL_VERSION`, re-run `./run.sh central`.
