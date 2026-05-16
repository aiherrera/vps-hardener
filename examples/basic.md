# Basic hardening

Zero extra env vars when root already has your SSH key.

## One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/aiherrera/vps-hardener/main/hardener.sh | \
  sudo bash
```

## What happens automatically

- Copies keys from `/root/.ssh/authorized_keys` (or `$SUDO_USER` when using sudo)
- Skips UFW 80/443 if nothing is listening on those ports
- Uses system timezone if not UTC
- Uses `sshd` port if not 22

## With an explicit key

```bash
curl -fsSL https://raw.githubusercontent.com/aiherrera/vps-hardener/main/hardener.sh | \
  sudo SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" bash
```

See [docs/configuration.md](../docs/configuration.md).
