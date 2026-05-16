# Configuration

Behavior is controlled through **environment variables** and optional **`PROFILE` presets**. Explicit env vars always win over presets and auto-detection.

## Minimal invocations

```bash
# Standard (keys on root)
sudo bash hardener.sh

# Tailscale only — one secret
sudo TAILSCALE_AUTHKEY=tskey-auth-xxx bash hardener.sh

# Presets
sudo PROFILE=web bash hardener.sh
sudo PROFILE=minimal bash hardener.sh
sudo PROFILE=lockdown bash hardener.sh   # over SSH: locks to your IP
sudo PROFILE=tailscale TAILSCALE_AUTHKEY=tskey-auth-xxx bash hardener.sh
```

## PROFILE presets

| PROFILE | Effect |
|---------|--------|
| _(unset)_ / `default` | Standard defaults + auto-detect |
| `minimal` | `ALLOW_HTTP=false`, `ALLOW_HTTPS=false` |
| `web` | Force UFW allow 80/443 |
| `tailscale` | `USE_TAILSCALE=true`, `KEEP_PUBLIC_SSH=false` (after join) |
| `lockdown` | `KEEP_PUBLIC_SSH=false`, `ALLOW_SSH_FROM` from SSH client IP |

## Auto-detection rules

| Trigger | Result |
|---------|--------|
| `TAILSCALE_AUTHKEY` or file at `TAILSCALE_AUTHKEY_FILE` | `USE_TAILSCALE=true` |
| Tailscale join succeeds | `KEEP_PUBLIC_SSH=false` unless you set `KEEP_PUBLIC_SSH` explicitly |
| `PROFILE=lockdown` or `KEEP_PUBLIC_SSH=false` without Tailscale | `ALLOW_SSH_FROM=<SSH_CLIENT>/32` if unset |
| Port 80/443 not listening | `ALLOW_HTTP` / `ALLOW_HTTPS` → `false` unless explicit or `PROFILE=web` |
| `sshd -T` port ≠ 22 | `SSH_PORT` updated if not set explicitly |
| System timezone ≠ UTC | `TIMEZONE` updated if not set explicitly |
| Hetzner metadata (optional) | `TAILSCALE_UP_EXTRA_ARGS=--hostname=...` |
| `DEPLOY_USER=auto` | Use `$SUDO_USER` when not root |

## Core variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DEPLOY_USER` | `deploy` | Sudo user (`NOPASSWD`); `auto` uses `$SUDO_USER` |
| `USE_TAILSCALE` | `false` | Install Tailscale |
| `KEEP_PUBLIC_SSH` | `true` | Allow SSH on public interface |
| `TAILSCALE_AUTHKEY` | _(unset)_ | Auth key for `tailscale up` |
| `TAILSCALE_AUTHKEY_FILE` | `/etc/vps-hardener/tailscale.authkey` | Fallback key file (mode 600) |
| `SSH_PORT` | `22` | SSH listen port |
| `SSH_PUBLIC_KEY` | _(unset)_ | One public key line |
| `SSH_AUTHORIZED_KEYS` | _(unset)_ | Keys or path to a file |
| `ALLOW_SSH_FROM` | _(unset)_ | Comma-separated CIDRs for SSH |

## `KEEP_PUBLIC_SSH` behavior

| `USE_TAILSCALE` | `KEEP_PUBLIC_SSH` | Result |
|-----------------|-------------------|--------|
| `false` | `true` | Public SSH on `SSH_PORT` |
| `false` | `false` | SSH only from `ALLOW_SSH_FROM` (required or auto from SSH) |
| `true` | `true` | Public + Tailscale SSH |
| `true` | `false` | Tailscale SSH only **after** node has Tailscale IPv4 |

If Tailscale is enabled but the node never joins, **public SSH stays open** with a warning.

## Optional variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `ALLOW_HTTP` | `true` | UFW TCP 80 |
| `ALLOW_HTTPS` | `true` | UFW TCP 443 |
| `INSTALL_MICRO` | `false` | Install micro via getmic.ro |
| `INSTALL_SNAP_MICRO` | `false` | Install micro via snap |
| `TIMEZONE` | `UTC` | System timezone |
| `TAILSCALE_UP_EXTRA_ARGS` | _(auto on Hetzner)_ | Extra `tailscale up` flags |

## SSH key preflight

Stops before changes unless keys exist from:

1. `/root/.ssh/authorized_keys`
2. `/home/$SUDO_USER/.ssh/authorized_keys` (when using `sudo`)
3. `SSH_PUBLIC_KEY` / `SSH_AUTHORIZED_KEYS`
4. Existing `DEPLOY_USER` keys (re-runs)

## Tailscale auth key file

On the server (optional):

```bash
sudo mkdir -p /etc/vps-hardener
echo 'tskey-auth-xxxxx' | sudo tee /etc/vps-hardener/tailscale.authkey
sudo chmod 600 /etc/vps-hardener/tailscale.authkey
sudo bash hardener.sh   # no TAILSCALE_AUTHKEY in command line
```

## Local overrides

```bash
set -a && source ./.env.local && set +a
sudo -E bash hardener.sh
```
