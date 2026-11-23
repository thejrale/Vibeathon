# Path B: DigitalOcean

Creates the server with an API token, then continues with [Path A](../path-a/README.md).

```bash
export DIGITALOCEAN_TOKEN=...          # Devin secret / your shell only
export ADMIN_EMAIL=admin@tuclinica.mx
./digitalocean.sh up                   # droplet s-2vcpu-2gb, Ubuntu 24.04, sfo3; cloud firewall 22/80/443; writes ../.env
../path-a/run.sh all                   # preflight, harden, docker, central, verify
./digitalocean.sh status
./digitalocean.sh down                 # deletes droplet + firewall (asks to confirm)
```

Overrides: `REGION` (e.g. `nyc3`), `SIZE`, `DROPLET_NAME`, `OPERATOR_USER` (default `eira-admin`, key-only SSH, passwordless sudo), `SSH_KEY_PATH` (default `~/.ssh/eira_central`, generated if missing).

The droplet's public IPv4 stays the same for the droplet's lifetime; the domain defaults to `<ip-with-dashes>.sslip.io`.
After provisioning, the token can be revoked: Path A and backups don't need it.
