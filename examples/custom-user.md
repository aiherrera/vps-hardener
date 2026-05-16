# Custom deploy user

## Named user

```bash
sudo DEPLOY_USER=admin bash hardener.sh
```

## Use the user who invoked sudo

```bash
ssh admin@server
sudo DEPLOY_USER=auto bash hardener.sh
```

Creates/uses `admin` and merges keys from `/home/admin/.ssh/authorized_keys`.

## Tailscale

```bash
sudo DEPLOY_USER=admin TAILSCALE_AUTHKEY=tskey-auth-xxx bash hardener.sh
```
