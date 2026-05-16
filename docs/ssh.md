# SSH hardening

SSH settings are written to **`/etc/ssh/sshd_config.d/99-vps-hardening.conf`** (overwritten each run). The main `sshd_config` is not edited with `sed`.

## Applied settings

- `Port` — from `SSH_PORT`
- `PermitRootLogin no`
- `PasswordAuthentication no`
- `PubkeyAuthentication yes`
- `AllowUsers` — `DEPLOY_USER` only
- Reduced `MaxAuthTries`, idle timeouts, `X11Forwarding no`

## Order of operations

1. Create `DEPLOY_USER` and ensure SSH keys exist (preflight)
2. Configure firewall (SSH port allowed as needed)
3. Write drop-in and reload `ssh` / `sshd`

Password authentication remains active until the final reload at the end of the script.

## Verify

```bash
sudo sshd -t
sudo sshd -T | grep -Ei 'permitrootlogin|passwordauthentication|port|allowusers'
```

## Test before disconnecting

```bash
ssh -p "$SSH_PORT" deploy@YOUR_SERVER_IP
```

## Changing the port

Set `SSH_PORT` before running. The script opens that port in UFW and sets `Port` in the drop-in.

## Related

- [configuration.md](configuration.md)
- [tailscale.md](tailscale.md)
- [troubleshooting.md](troubleshooting.md)
