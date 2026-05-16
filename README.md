# vps-hardener

Opinionated, one-shot VPS hardening for fresh **Debian/Ubuntu** servers (Hetzner-friendly defaults). Run directly from GitHub with `curl` and `bash`, or clone the repo and execute locally.

## Install URL

```text
https://raw.githubusercontent.com/aiherrera/vps-hardener/main/hardener.sh
```

## Minimal commands

| Goal | Command |
|------|---------|
| Standard hardening | `curl -fsSL https://raw.githubusercontent.com/aiherrera/vps-hardener/main/hardener.sh \| sudo bash` |
| Tailscale lockdown | `curl -fsSL https://raw.githubusercontent.com/aiherrera/vps-hardener/main/hardener.sh \| sudo TAILSCALE_AUTHKEY=tskey-... bash` |
| Web server | `curl -fsSL https://raw.githubusercontent.com/aiherrera/vps-hardener/main/hardener.sh \| sudo PROFILE=web bash` |
| No HTTP/HTTPS in firewall | `curl -fsSL https://raw.githubusercontent.com/aiherrera/vps-hardener/main/hardener.sh \| sudo PROFILE=minimal bash` |
| SSH only from your current IP | `curl -fsSL https://raw.githubusercontent.com/aiherrera/vps-hardener/main/hardener.sh \| sudo PROFILE=lockdown bash` |

> **Warning:** Requires SSH keys on the server (`/root/.ssh/authorized_keys`, `SUDO_USER` keys, or `SSH_PUBLIC_KEY`). The script exits otherwise to prevent lockout.

## What it does

- Updates the system and installs common admin packages
- Creates `deploy` user (override with `DEPLOY_USER` or `DEPLOY_USER=auto`) with sudo and your SSH keys
- Hardens OpenSSH via `/etc/ssh/sshd_config.d/99-vps-hardening.conf`
- Configures UFW (auto-opens 80/443 only if those ports are already listening, unless `PROFILE=web`)
- Optional Tailscale — `TAILSCALE_AUTHKEY` alone enables Tailscale and can close public SSH after join
- fail2ban when public SSH remains open
- unattended-upgrades, chrony, sysctl hardening, persistent journald

## Automation

The script applies **PROFILE presets** and **auto-detection** when you omit variables:

- `TAILSCALE_AUTHKEY` → `USE_TAILSCALE=true`
- Tailscale join success → `KEEP_PUBLIC_SSH=false` (unless you set `KEEP_PUBLIC_SSH=true`)
- `PROFILE=lockdown` over SSH → `ALLOW_SSH_FROM=<your-ip>/32`
- No listener on 80/443 → skips UFW allow for those ports
- `sshd -T` / system timezone → `SSH_PORT` / `TIMEZONE` when still at defaults

Precedence: **explicit env var > PROFILE > auto-detect**.

See [docs/configuration.md](docs/configuration.md).

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PROFILE` | _(unset)_ | `minimal`, `web`, `tailscale`, `lockdown` |
| `DEPLOY_USER` | `deploy` | Sudo user (`auto` = use `$SUDO_USER`) |
| `TAILSCALE_AUTHKEY` | _(unset)_ | Tailscale auth key; also read from `TAILSCALE_AUTHKEY_FILE` |
| `USE_TAILSCALE` | `false` | Install Tailscale (auto `true` if auth key set) |
| `KEEP_PUBLIC_SSH` | `true` | Public WAN SSH (auto `false` after Tailscale join) |
| `SSH_PORT` | `22` | SSH port (auto from `sshd -T` if non-default) |
| `SSH_PUBLIC_KEY` | _(unset)_ | Public key line for deploy user |
| `ALLOW_SSH_FROM` | _(unset)_ | CIDR allow list for SSH (auto from SSH session on lockdown) |
| `ALLOW_HTTP` / `ALLOW_HTTPS` | `true` | UFW web ports (auto `false` if not listening) |
| `TIMEZONE` | `UTC` | System timezone (auto from OS if set) |
| `INSTALL_MICRO` | `false` | Install micro editor |

## Examples

| Scenario | Guide |
|----------|--------|
| Minimal hardening | [examples/basic.md](examples/basic.md) |
| No web firewall ports | [examples/minimal.md](examples/minimal.md) |
| Tailscale-only SSH | [examples/tailscale.md](examples/tailscale.md) |
| Custom deploy user | [examples/custom-user.md](examples/custom-user.md) |
| Production checklist | [examples/production.md](examples/production.md) |

## Documentation

- [Configuration](docs/configuration.md)
- [Firewall](docs/firewall.md)
- [SSH](docs/ssh.md)
- [Tailscale](docs/tailscale.md)
- [Troubleshooting](docs/troubleshooting.md)

## Development

```bash
shellcheck hardener.sh
bats tests/defaults.bats   # optional
```

## License

[MIT](LICENSE) — Copyright (c) 2026 Alain Iglesias
