# Firewall

The hardener configures **UFW** with default-deny inbound and allows only what you need.

## Default rules

| Traffic | When |
|---------|------|
| SSH on public `SSH_PORT` | `KEEP_PUBLIC_SSH=true`, or Tailscale not joined yet |
| SSH on `tailscale0` | `USE_TAILSCALE=true` |
| SSH from CIDRs | `KEEP_PUBLIC_SSH=false` without Tailscale — uses `ALLOW_SSH_FROM` |
| TCP 80 / 443 | `ALLOW_HTTP=true` / `ALLOW_HTTPS=true` (defaults) |
| Outbound | Allowed |
| Established / related | Allowed by UFW defaults |

## Tailscale-only SSH

```bash
sudo USE_TAILSCALE=true KEEP_PUBLIC_SSH=false TAILSCALE_AUTHKEY=tskey-auth-xxx bash hardener.sh
```

Public SSH is removed only after `tailscale ip -4` succeeds.

## CIDR-restricted SSH (no Tailscale)

```bash
sudo KEEP_PUBLIC_SSH=false ALLOW_SSH_FROM=203.0.113.10/32,198.51.100.0/24 bash hardener.sh
```

## Inspect rules

```bash
sudo ufw status verbose
```

## Recovery

From provider console:

```bash
sudo ufw disable
# or remove a rule:
sudo ufw status numbered
sudo ufw delete <number>
```

See [troubleshooting.md](troubleshooting.md).
