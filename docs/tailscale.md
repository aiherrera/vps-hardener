# Tailscale

## One variable (recommended)

```bash
sudo TAILSCALE_AUTHKEY=tskey-auth-xxxxx bash hardener.sh
```

Infers `USE_TAILSCALE=true` and closes public SSH after a successful join.

## Auth key file

Default path: `/etc/vps-hardener/tailscale.authkey` (override with `TAILSCALE_AUTHKEY_FILE`).

## PROFILE=tailscale

Same as setting `USE_TAILSCALE=true` and `KEEP_PUBLIC_SSH=false` before join; still requires a successful join to close public SSH.

## Hetzner hostname

On Hetzner cloud servers, the script may set `TAILSCALE_UP_EXTRA_ARGS=--hostname=<metadata>` automatically when `curl` is available.

## Without auth key

Public SSH remains open until the node joins the tailnet. Run `sudo tailscale up`, then re-run hardening or set `KEEP_PUBLIC_SSH=false` manually in UFW.

See [troubleshooting.md](troubleshooting.md).
