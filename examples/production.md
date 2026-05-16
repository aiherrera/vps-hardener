# Production deployment

## Recommended one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/aiherrera/vps-hardener/main/hardener.sh | \
  sudo PROFILE=tailscale TAILSCALE_AUTHKEY=tskey-auth-xxxxx bash
```

Same as `TAILSCALE_AUTHKEY` alone — `PROFILE=tailscale` is optional when the auth key is set.

## Pre-flight checklist

- [ ] `/root/.ssh/authorized_keys` has your key (or `SSH_PUBLIC_KEY`)
- [ ] Tailscale ephemeral auth key ready
- [ ] Provider console tested
- [ ] Snapshot taken
- [ ] Staging run completed

## Post-flight verification

- [ ] `ssh deploy@<tailscale-hostname>` works
- [ ] Public SSH closed (`sudo ufw status verbose`)
- [ ] Effective config printed at end of script lists `PUBLIC_SSH_OPEN=false`
- [ ] `sudo sshd -T | grep -Ei 'permitrootlogin|passwordauthentication|allowusers'`

## Web-facing production

```bash
sudo PROFILE=web TAILSCALE_AUTHKEY=tskey-auth-xxxxx bash hardener.sh
```

## Office IP only (no Tailscale)

SSH from your machine, then:

```bash
sudo PROFILE=lockdown bash hardener.sh
```

Auto-sets `ALLOW_SSH_FROM` to your current IP.
