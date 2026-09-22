# Ops scripts (persistent copy)

Live on the VPS at `/opt/banan/infra/ops/` (the git checkout — survives reboots;
`/tmp` is wiped on every reboot). Run them with `ssh banan "bash /opt/banan/infra/ops/<name>.sh"`.

| Script | What |
|---|---|
| `deploy-backend-only.sh` | `git pull`, rebuild + restart backend, wait for `/health` (prints `BACKEND_DEPLOY_OK`) |
| `swap-customer.sh` / `swap-merchant.sh` / `swap-internal.sh` | atomically replace a web app from `/tmp/banan-web-<app>.tgz`, restart caddy (`SWAP_OK`) |
| `run-products.sh` | run `/tmp/products.sql` inside the postgres container (`psql -f`) |

The tarball / SQL inputs still go through `/tmp` (scp them right before running).
