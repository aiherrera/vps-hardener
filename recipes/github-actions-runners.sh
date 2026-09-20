#!/usr/bin/env bash
set -euo pipefail

# Spin up N GitHub Actions self-hosted runners on one Linux host.
# Required env: RUNNER_COUNT, GITHUB_URL, RUNNER_TOKEN

log() { printf "\n==> %s\n" "$*"; }
fail() { printf "ERROR: %s\n" "$*" >&2; exit 1; }

[[ ${EUID} -eq 0 ]] || fail "Run this recipe as root (sudo)."

RUNNER_COUNT="${RUNNER_COUNT:-}"
GITHUB_URL="${GITHUB_URL:-}"
RUNNER_TOKEN="${RUNNER_TOKEN:-}"
RUNNER_USER="${RUNNER_USER:-github-runner}"
RUNNER_PREFIX="${RUNNER_PREFIX:-$(hostname -s)}"
RUNNER_LABELS="${RUNNER_LABELS:-}"
RUNNER_GROUP="${RUNNER_GROUP:-Default}"
RUNNER_BASE_DIR="${RUNNER_BASE_DIR:-/home/${RUNNER_USER}}"
RUNNER_VERSION="${RUNNER_VERSION:-}"
INSTALL_DOCKER="${INSTALL_DOCKER:-true}"

[[ "$RUNNER_COUNT" =~ ^[1-9][0-9]*$ ]] || fail "RUNNER_COUNT must be a positive integer."
[[ -n "$GITHUB_URL" ]] || fail "GITHUB_URL is required."
[[ -n "$RUNNER_TOKEN" ]] || fail "RUNNER_TOKEN is required."

export DEBIAN_FRONTEND=noninteractive

log "Installing base packages"
apt-get update
apt-get install -y curl ca-certificates git jq tar

if [[ "$INSTALL_DOCKER" == "true" ]]; then
  if ! command -v docker >/dev/null 2>&1; then
    log "Installing Docker"
    curl -fsSL https://get.docker.com | sh
  fi
  systemctl enable --now docker
fi

if ! id "$RUNNER_USER" >/dev/null 2>&1; then
  log "Creating service user $RUNNER_USER"
  useradd --create-home --shell /bin/bash "$RUNNER_USER"
fi

if command -v docker >/dev/null 2>&1; then
  usermod -aG docker "$RUNNER_USER"
fi

mkdir -p "$RUNNER_BASE_DIR"
chown "$RUNNER_USER:$RUNNER_USER" "$RUNNER_BASE_DIR"

if [[ -z "$RUNNER_VERSION" ]]; then
  log "Resolving latest GitHub Actions runner version"
  RUNNER_VERSION="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/^v//')"
fi

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) RUNNER_ARCH="x64" ;;
  aarch64|arm64) RUNNER_ARCH="arm64" ;;
  *) fail "Unsupported architecture: $ARCH" ;;
esac

RUNNER_TARBALL="actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
RUNNER_DOWNLOAD_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_TARBALL}"
CACHE_DIR="/var/cache/github-actions-runner"
mkdir -p "$CACHE_DIR"

if [[ ! -f "$CACHE_DIR/$RUNNER_TARBALL" ]]; then
  log "Downloading GitHub Actions runner ${RUNNER_VERSION}"
  curl -fL "$RUNNER_DOWNLOAD_URL" -o "$CACHE_DIR/$RUNNER_TARBALL"
fi

for i in $(seq 1 "$RUNNER_COUNT"); do
  suffix="$(printf '%02d' "$i")"
  name="${RUNNER_PREFIX}-${suffix}"
  dir="${RUNNER_BASE_DIR}/actions-runner-${suffix}"

  if [[ -f "$dir/.runner" ]]; then
    log "Runner $name already configured at $dir; skipping registration"
  else
    log "Configuring runner $name"
    mkdir -p "$dir"
    tar -xzf "$CACHE_DIR/$RUNNER_TARBALL" -C "$dir"
    chown -R "$RUNNER_USER:$RUNNER_USER" "$dir"

    args=(--unattended --url "$GITHUB_URL" --token "$RUNNER_TOKEN" --name "$name" --work "_work" --replace)
    [[ -n "$RUNNER_LABELS" ]] && args+=(--labels "$RUNNER_LABELS")
    [[ -n "$RUNNER_GROUP" && "$RUNNER_GROUP" != "Default" ]] && args+=(--runnergroup "$RUNNER_GROUP")
    runuser -u "$RUNNER_USER" -- "$dir/config.sh" "${args[@]}"
  fi

  service_file="$(find /etc/systemd/system -maxdepth 1 -type f -name "actions.runner.*.${name}.service" -print -quit 2>/dev/null || true)"
  if [[ -z "$service_file" ]]; then
    log "Installing systemd service for $name"
    (cd "$dir" && ./svc.sh install "$RUNNER_USER")
  fi

  log "Starting service for $name"
  (cd "$dir" && ./svc.sh start)
done

log "Configured runners"
systemctl list-units --type=service --all "actions.runner.*" --no-pager || true

cat <<EOF

Done.

Notes:
- One self-hosted runner handles one job at a time; RUNNER_COUNT sets host-level concurrency.
- Generate a fresh registration token immediately before running this recipe.
- Jobs sharing fixed host ports/container names can collide; isolate them or serialize with workflow concurrency.
- Re-running with the same RUNNER_COUNT preserves already-configured runner directories.
EOF