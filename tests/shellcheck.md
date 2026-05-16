# ShellCheck

Static analysis for [hardener.sh](../hardener.sh) using [ShellCheck](https://www.shellcheck.net/).

## Install

```bash
brew install shellcheck          # macOS
sudo apt-get install -y shellcheck   # Debian/Ubuntu
```

## Run locally

```bash
shellcheck hardener.sh
```

## Bats tests (helpers)

Helper logic is duplicated in [tests/lib/helpers.sh](lib/helpers.sh) for fast tests without a VM:

```bash
brew install bats-core   # macOS
sudo apt-get install -y bats   # Debian/Ubuntu
bats tests/defaults.bats
```

When changing `get_ssh_client_ip`, `normalize_bool`, or `authorized_keys_has_entries` in `hardener.sh`, update `tests/lib/helpers.sh` to match.

## CI

GitHub Actions runs ShellCheck on push and pull request (`.github/workflows/shellcheck.yml`).
