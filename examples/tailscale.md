# Tailscale-only SSH

## Recommended (one variable)

```bash
curl -fsSL https://raw.githubusercontent.com/aiherrera/vps-hardener/main/hardener.sh | \
  sudo TAILSCALE_AUTHKEY=tskey-auth-xxxxx bash
```

The script automatically:

- Sets `USE_TAILSCALE=true`
- Joins the tailnet with your auth key
- Closes public SSH after `tailscale ip -4` succeeds

## With PROFILE (equivalent)

```bash
sudo PROFILE=tailscale TAILSCALE_AUTHKEY=tskey-auth-xxxxx bash hardener.sh
```

## Auth key file on server

```bash
sudo install -d -m 700 /etc/vps-hardener
echo 'tskey-auth-xxxxx' | sudo tee /etc/vps-hardener/tailscale.authkey
sudo chmod 600 /etc/vps-hardener/tailscale.authkey
sudo bash hardener.sh
```

## Without auth key

Public SSH stays open until you run `sudo tailscale up`, then re-run with `TAILSCALE_AUTHKEY` or `PROFILE=tailscale`.

See [docs/tailscale.md](../docs/tailscale.md).
