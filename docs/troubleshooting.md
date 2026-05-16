# Troubleshooting

## Script exits: "No SSH keys for deploy"

You logged in with a password and `/root/.ssh/authorized_keys` is empty.

**Fix (before re-running):**

```bash
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo 'ssh-ed25519 AAAA... your-key' >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
```

Or pass a key inline:

```bash
sudo SSH_PUBLIC_KEY='ssh-ed25519 AAAA...' bash hardener.sh
```

## Locked out of SSH

1. Open the provider console (Hetzner, DO, AWS, etc.).
2. Check firewall: `sudo ufw status verbose`
3. Check SSH: `sudo systemctl status ssh`; `sudo sshd -t`
4. Temporarily allow SSH: `sudo ufw allow 22/tcp`
5. Inspect drop-in: `cat /etc/ssh/sshd_config.d/99-vps-hardening.conf`

## Tailscale-only but still need public SSH

The node was not on the tailnet when the script ran. Either:

- Set `TAILSCALE_AUTHKEY` and re-run, or
- Run `sudo tailscale up` from console, then re-run with `KEEP_PUBLIC_SSH=false`

## `KEEP_PUBLIC_SSH=false` without Tailscale

Requires `ALLOW_SSH_FROM`:

```bash
sudo KEEP_PUBLIC_SSH=false ALLOW_SSH_FROM=203.0.113.5/32 bash hardener.sh
```

## fail2ban banned your IP

From console:

```bash
sudo fail2ban-client status sshd
sudo fail2ban-client set sshd unbanip YOUR_IP
```

## Invalid TIMEZONE

```bash
timedatectl list-timezones | grep -i america
sudo TIMEZONE=America/New_York bash hardener.sh
```

## Report an issue

Include:

- `/etc/os-release`
- Exact command and env vars (redact `TAILSCALE_AUTHKEY`)
- `sudo ufw status verbose`
- `sudo sshd -T | grep -Ei 'permitroot|password|allowusers|port'`
