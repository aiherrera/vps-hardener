# Minimal firewall profile

For app servers, databases, or bastions that should not expose HTTP/HTTPS on the firewall.

## One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/aiherrera/vps-hardener/main/hardener.sh | \
  sudo PROFILE=minimal bash
```

## What changes

- `ALLOW_HTTP=false` and `ALLOW_HTTPS=false` in UFW
- SSH and other hardening unchanged from the default run

## Auto-detect vs PROFILE

On a fresh VPS with nothing listening on 80/443, the default run **already** skips those ports via auto-detection. Use `PROFILE=minimal` when you want to force them closed even if a service later binds to 80/443 during the same run (unlikely) or to make intent explicit in docs/automation.

## Equivalent manual flags

```bash
sudo ALLOW_HTTP=false ALLOW_HTTPS=false bash hardener.sh
```
