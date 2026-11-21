# Create a small VPS for Path A

About 15 minutes. Result: a public IP, a non-root sudo user, and an SSH key, which is everything `run.sh` needs.

## 1. Make an SSH key (on your computer)

macOS / Linux / Windows PowerShell:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/eira_central -N "" -C "eira-central"
```

- `~/.ssh/eira_central.pub`: public key, pasted into the provider in step 2
- `~/.ssh/eira_central`: private key, never shared except through Devin's secret form

## 2. Create the server

Any provider works. Pick the region closest to the clinic.

| Setting | Value |
|---|---|
| Image | Ubuntu 24.04 LTS x64 |
| Size | 2 GB RAM, 1–2 vCPU, 25 GB+ SSD (typically US$10–20/month) |
| Region | Closest to the clinic (e.g. Vultr Mexico City; DigitalOcean SFO/NYC; AWS Lightsail `us-east-2`) |
| Authentication | SSH key: paste the contents of `eira_central.pub` |
| Extras | Optional: provider backups/snapshots. No managed database needed. |

Provider entry points:
- DigitalOcean: Create → Droplets
- Vultr: Deploy → Cloud Compute
- AWS Lightsail: Create instance → Linux → OS only → Ubuntu 24.04
- GCP: Compute Engine → VM instances → `e2-small`, allow HTTP/HTTPS traffic

If the provider has its own firewall, allow inbound **TCP 22, 80, 443** from anywhere.

Copy the server's **public IPv4** (four numbers, e.g. `164.90.12.34`).

## 3. Create the sudo user (first and only time as root)

Lightsail/GCP log in as `ubuntu` instead of `root`; use `sudo` before each command below.

```bash
ssh -i ~/.ssh/eira_central root@<IP>

adduser dra.rojas                      # set a strong password: this is the sudo password
usermod -aG sudo dra.rojas
mkdir -p /home/dra.rojas/.ssh
cp ~/.ssh/authorized_keys /home/dra.rojas/.ssh/
chown -R dra.rojas:dra.rojas /home/dra.rojas/.ssh
chmod 700 /home/dra.rojas/.ssh && chmod 600 /home/dra.rojas/.ssh/authorized_keys
exit
```

## 4. Check it works

```bash
ssh -i ~/.ssh/eira_central dra.rojas@<IP> 'sudo -v && echo SUDO-OK'
```

You should be asked for the password from step 3, then see `SUDO-OK`.

## 5. Hand over to Devin

- In chat: the IP and the username (`dra.rojas`).
- Secret forms: contents of `~/.ssh/eira_central` (the private key, including the BEGIN/END lines) and the sudo password.
- Domain: `<ip-with-dashes>.sslip.io` (e.g. `164-90-12-34.sslip.io`) until `piloto-eira.mx` is registered. Switching later means changing `DOMAIN` in `/opt/central/.env` and re-running `./run.sh central`.

`run.sh harden` then turns off password login over SSH. Key-based login and the sudo password keep working.

To give other people their own login later (web or SSH), see [Share access with other people](README.md#share-access-with-other-people).
