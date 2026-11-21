# Deploy

ODK Central deployment (Phase 2). Two entry paths, same result. See `docs/MVP_SCOPE.md`.

- **Path A:** existing server. Needs public IP, SSH key, sudo user.
- **Path B:** Devin provisions a VM on DigitalOcean, AWS, or GCP with an API token, then continues as Path A.

Nothing here contains secrets. `.env`, keys, and tokens are git-ignored; see `env.example` for the variable names.
