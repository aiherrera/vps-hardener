#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# VPS hardener (Debian/Ubuntu) — Hetzner-friendly defaults
# curl -fsSL https://raw.githubusercontent.com/aiherrera/vps-hardener/main/hardener.sh | sudo bash
# curl -fsSL https://raw.githubusercontent.com/aiherrera/vps-hardener/main/hardener.sh | sudo TAILSCALE_AUTHKEY=tskey-auth-xxx bash
# curl -fsSL https://raw.githubusercontent.com/aiherrera/vps-hardener/main/hardener.sh | sudo PROFILE=web bash
# ============================================================

# --- explicit env tracking (before defaults) ---
env_was_set() { [[ -n "${!1+set}" ]]; }

DEPLOY_USER_EXPLICIT=false
env_was_set DEPLOY_USER && DEPLOY_USER_EXPLICIT=true
DEPLOY_USER="${DEPLOY_USER:-deploy}"

TIMEZONE_EXPLICIT=false
env_was_set TIMEZONE && TIMEZONE_EXPLICIT=true
TIMEZONE="${TIMEZONE:-UTC}"

SSH_PORT_EXPLICIT=false
env_was_set SSH_PORT && SSH_PORT_EXPLICIT=true
SSH_PORT="${SSH_PORT:-22}"

USE_TAILSCALE_EXPLICIT=false
env_was_set USE_TAILSCALE && USE_TAILSCALE_EXPLICIT=true
USE_TAILSCALE="${USE_TAILSCALE:-false}"

KEEP_PUBLIC_SSH_EXPLICIT=false
env_was_set KEEP_PUBLIC_SSH && KEEP_PUBLIC_SSH_EXPLICIT=true
KEEP_PUBLIC_SSH="${KEEP_PUBLIC_SSH:-true}"

INSTALL_MICRO="${INSTALL_MICRO:-false}"
INSTALL_SNAP_MICRO="${INSTALL_SNAP_MICRO:-false}"

ALLOW_HTTP_EXPLICIT=false
env_was_set ALLOW_HTTP && ALLOW_HTTP_EXPLICIT=true
ALLOW_HTTP="${ALLOW_HTTP:-true}"

ALLOW_HTTPS_EXPLICIT=false
env_was_set ALLOW_HTTPS && ALLOW_HTTPS_EXPLICIT=true
ALLOW_HTTPS="${ALLOW_HTTPS:-true}"

ALLOW_SSH_FROM_EXPLICIT=false
env_was_set ALLOW_SSH_FROM && ALLOW_SSH_FROM_EXPLICIT=true
ALLOW_SSH_FROM="${ALLOW_SSH_FROM:-}"

PROFILE_EXPLICIT=false
env_was_set PROFILE && PROFILE_EXPLICIT=true
PROFILE="${PROFILE:-}"

TAILSCALE_AUTHKEY_EXPLICIT=false
env_was_set TAILSCALE_AUTHKEY && TAILSCALE_AUTHKEY_EXPLICIT=true
TAILSCALE_AUTHKEY="${TAILSCALE_AUTHKEY:-}"
TAILSCALE_AUTHKEY_FILE="${TAILSCALE_AUTHKEY_FILE:-/etc/vps-hardener/tailscale.authkey}"

SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"
SSH_AUTHORIZED_KEYS="${SSH_AUTHORIZED_KEYS:-}"

SSHD_DROPIN="/etc/ssh/sshd_config.d/99-vps-hardening.conf"
PUBLIC_SSH_OPEN="true"
PROFILE_FORCE_WEB_PORTS="false"

declare -a AUTO_NOTES=()

normalize_bool() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

auto_note() {
  AUTO_NOTES+=("$1")
}

log() {
  echo ""
  echo ">>> $1"
}

log_auto() {
  echo ">>> Auto: $1"
  auto_note "$1"
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

port_is_listening() {
  local port="$1"
  ss -tlnH 2>/dev/null | grep -qE ":${port}([^0-9]|$)"
}

get_ssh_client_ip() {
  local client="${SSH_CLIENT:-}"
  if [[ -z "$client" && -n "${SSH_CONNECTION:-}" ]]; then
    client="${SSH_CONNECTION%% *}"
  fi
  echo "${client%%:*}"
}

detect_ssh_port() {
  if [[ "$SSH_PORT_EXPLICIT" == "true" ]]; then
    return 0
  fi
  local detected
  detected="$(sshd -T 2>/dev/null | awk '/^port / {print $2; exit}')" || true
  if [[ -n "$detected" && "$detected" != "22" ]]; then
    SSH_PORT="$detected"
    log_auto "SSH_PORT=$SSH_PORT (from sshd -T)"
  fi
}

detect_timezone() {
  if [[ "$TIMEZONE_EXPLICIT" == "true" ]]; then
    return 0
  fi
  local detected=""
  if command -v timedatectl >/dev/null 2>&1; then
    detected="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
  fi
  if [[ -z "$detected" && -f /etc/timezone ]]; then
    detected="$(tr -d '[:space:]' </etc/timezone)"
  fi
  if [[ -n "$detected" && "$detected" != "UTC" ]]; then
    TIMEZONE="$detected"
    log_auto "TIMEZONE=$TIMEZONE (from system)"
  fi
}

detect_firewall_ports() {
  if [[ "$PROFILE_FORCE_WEB_PORTS" == "true" ]]; then
    return 0
  fi
  if [[ "$ALLOW_HTTP_EXPLICIT" != "true" ]] && ! port_is_listening 80; then
    ALLOW_HTTP="false"
    log_auto "ALLOW_HTTP=false (port 80 not listening)"
  fi
  if [[ "$ALLOW_HTTPS_EXPLICIT" != "true" ]] && ! port_is_listening 443; then
    ALLOW_HTTPS="false"
    log_auto "ALLOW_HTTPS=false (port 443 not listening)"
  fi
}

infer_allow_ssh_from_client() {
  if [[ -n "$ALLOW_SSH_FROM" ]]; then
    return 0
  fi
  local client_ip
  client_ip="$(get_ssh_client_ip)"
  if [[ -n "$client_ip" ]]; then
    ALLOW_SSH_FROM="${client_ip}/32"
    log_auto "ALLOW_SSH_FROM=$ALLOW_SSH_FROM (from SSH session)"
  fi
}

load_tailscale_authkey_file() {
  if [[ -n "$TAILSCALE_AUTHKEY" ]]; then
    return 0
  fi
  if [[ -f "$TAILSCALE_AUTHKEY_FILE" ]]; then
    TAILSCALE_AUTHKEY="$(tr -d '[:space:]' <"$TAILSCALE_AUTHKEY_FILE")"
    if [[ -n "$TAILSCALE_AUTHKEY" ]]; then
      log_auto "TAILSCALE_AUTHKEY loaded from $TAILSCALE_AUTHKEY_FILE"
    fi
  fi
}

hetzner_hostname_hint() {
  if [[ -n "${TAILSCALE_UP_EXTRA_ARGS:-}" ]] || ! command -v curl >/dev/null 2>&1; then
    return 0
  fi
  local hostname
  hostname="$(curl -fsS --max-time 1 \
    http://169.254.169.254/hetzner/v1/metadata/hostname 2>/dev/null || true)"
  if [[ -n "$hostname" ]]; then
    TAILSCALE_UP_EXTRA_ARGS="--hostname=${hostname}"
    log_auto "TAILSCALE_UP_EXTRA_ARGS=--hostname=${hostname} (Hetzner metadata)"
  fi
}

apply_profile_preset() {
  local profile
  profile="$(normalize_bool "${PROFILE:-}")"
  [[ -z "$profile" || "$profile" == "default" ]] && return 0

  case "$profile" in
    minimal)
      if [[ "$ALLOW_HTTP_EXPLICIT" != "true" ]]; then ALLOW_HTTP="false"; fi
      if [[ "$ALLOW_HTTPS_EXPLICIT" != "true" ]]; then ALLOW_HTTPS="false"; fi
      auto_note "PROFILE=minimal"
      ;;
    web)
      ALLOW_HTTP="true"
      ALLOW_HTTPS="true"
      PROFILE_FORCE_WEB_PORTS="true"
      auto_note "PROFILE=web"
      ;;
    tailscale)
      if [[ "$USE_TAILSCALE_EXPLICIT" != "true" ]]; then USE_TAILSCALE="true"; fi
      if [[ "$KEEP_PUBLIC_SSH_EXPLICIT" != "true" ]]; then KEEP_PUBLIC_SSH="false"; fi
      auto_note "PROFILE=tailscale"
      ;;
    lockdown)
      if [[ "$KEEP_PUBLIC_SSH_EXPLICIT" != "true" ]]; then KEEP_PUBLIC_SSH="false"; fi
      infer_allow_ssh_from_client
      auto_note "PROFILE=lockdown"
      ;;
    *)
      die "Unknown PROFILE=$PROFILE (use: minimal, web, tailscale, lockdown, or default)"
      ;;
  esac
}

resolve_deploy_user() {
  if [[ "$DEPLOY_USER" != "auto" ]]; then
    return 0
  fi
  if [[ -n "${SUDO_USER:-}" ]] && [[ "$SUDO_USER" != "root" ]]; then
    DEPLOY_USER="$SUDO_USER"
    log_auto "DEPLOY_USER=$DEPLOY_USER (DEPLOY_USER=auto)"
  else
    DEPLOY_USER="deploy"
    log_auto "DEPLOY_USER=deploy (DEPLOY_USER=auto, no SUDO_USER)"
  fi
}

apply_defaults() {
  log "Applying defaults and PROFILE preset"

  load_tailscale_authkey_file

  if [[ -n "$TAILSCALE_AUTHKEY" ]] && [[ "$USE_TAILSCALE_EXPLICIT" != "true" ]]; then
    USE_TAILSCALE="true"
    log_auto "USE_TAILSCALE=true (TAILSCALE_AUTHKEY set)"
  fi

  apply_profile_preset
  resolve_deploy_user

  if [[ "$KEEP_PUBLIC_SSH" == "false" && "$USE_TAILSCALE" != "true" ]]; then
    infer_allow_ssh_from_client
  fi

  detect_ssh_port
  detect_timezone
  detect_firewall_ports
  hetzner_hostname_hint
}

normalize_bools() {
  USE_TAILSCALE="$(normalize_bool "$USE_TAILSCALE")"
  KEEP_PUBLIC_SSH="$(normalize_bool "$KEEP_PUBLIC_SSH")"
  INSTALL_MICRO="$(normalize_bool "$INSTALL_MICRO")"
  INSTALL_SNAP_MICRO="$(normalize_bool "$INSTALL_SNAP_MICRO")"
  ALLOW_HTTP="$(normalize_bool "$ALLOW_HTTP")"
  ALLOW_HTTPS="$(normalize_bool "$ALLOW_HTTPS")"
}

validate_inputs() {
  if [[ ! "$DEPLOY_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    die "Invalid DEPLOY_USER: $DEPLOY_USER"
  fi

  if [[ ! "$SSH_PORT" =~ ^[0-9]+$ ]] || (( SSH_PORT < 1 || SSH_PORT > 65535 )); then
    die "Invalid SSH_PORT: $SSH_PORT (use 1-65535)"
  fi

  if ! timedatectl list-timezones 2>/dev/null | grep -Fxq "$TIMEZONE"; then
    die "Invalid TIMEZONE: $TIMEZONE (see: timedatectl list-timezones)"
  fi

  if [[ "$KEEP_PUBLIC_SSH" == "false" && "$USE_TAILSCALE" != "true" && -z "$ALLOW_SSH_FROM" ]]; then
    die "KEEP_PUBLIC_SSH=false requires USE_TAILSCALE=true, ALLOW_SSH_FROM, or PROFILE=lockdown over SSH."
  fi
}

authorized_keys_has_entries() {
  local file="$1"
  [[ -f "$file" ]] && grep -qvE '^\s*#|^\s*$' "$file" 2>/dev/null
}

sudo_user_authorized_keys_path() {
  if [[ -n "${SUDO_USER:-}" ]] && [[ "$SUDO_USER" != "root" ]]; then
    echo "/home/$SUDO_USER/.ssh/authorized_keys"
  fi
}

require_ssh_credentials() {
  local deploy_keys="/home/$DEPLOY_USER/.ssh/authorized_keys"
  local sudo_keys
  sudo_keys="$(sudo_user_authorized_keys_path || true)"

  if [[ -n "${SSH_PUBLIC_KEY// }" ]]; then
    return 0
  fi
  if authorized_keys_has_entries /root/.ssh/authorized_keys; then
    return 0
  fi
  if [[ -n "${SSH_AUTHORIZED_KEYS// }" ]]; then
    return 0
  fi
  if authorized_keys_has_entries "$deploy_keys"; then
    return 0
  fi
  if [[ -n "$sudo_keys" ]] && authorized_keys_has_entries "$sudo_keys"; then
    return 0
  fi

  echo "WARNING: No SSH keys found. This script disables root and password login." >&2
  echo "WARNING: Set SSH_PUBLIC_KEY or populate /root/.ssh/authorized_keys before continuing." >&2
  echo "" >&2
  echo "Example:" >&2
  echo "  sudo SSH_PUBLIC_KEY=\"\$(cat ~/.ssh/id_ed25519.pub)\" bash hardener.sh" >&2
  die "Stopping to prevent SSH lockout."
}

ufw_status_has() {
  local pattern="$1"
  ufw status verbose 2>/dev/null | grep -qE "$pattern"
}

ufw_allow_once() {
  local rule="$1"
  local pattern="$2"
  if ufw_status_has "$pattern"; then
    echo "UFW rule already present: $rule"
  else
    # shellcheck disable=SC2086
    ufw allow $rule
  fi
}

tailscale_has_ipv4() {
  command -v tailscale >/dev/null 2>&1 && tailscale ip -4 >/dev/null 2>&1
}

install_tailscale() {
  if command -v tailscale >/dev/null 2>&1; then
    echo "Tailscale already installed."
    return 0
  fi
  apt install -y curl
  curl -fsSL https://tailscale.com/install.sh | sh
}

close_public_ssh_ufw() {
  ufw delete allow "$SSH_PORT/tcp" >/dev/null 2>&1 || true
  PUBLIC_SSH_OPEN="false"
  echo "Public SSH closed; SSH allowed on tailscale0 only."
}

bootstrap_tailscale() {
  systemctl enable --now tailscaled

  if [[ -z "$TAILSCALE_AUTHKEY" ]]; then
    log "Tailscale auth key not set; run 'sudo tailscale up' after hardening if needed"
    return 0
  fi

  log "Joining Tailscale with auth key"
  # shellcheck disable=SC2086
  tailscale up --auth-key="$TAILSCALE_AUTHKEY" ${TAILSCALE_UP_EXTRA_ARGS:-}

  if ! tailscale_has_ipv4; then
    die "Tailscale install finished but node has no Tailscale IPv4. Public SSH left open."
  fi

  echo "Tailscale connected: $(tailscale ip -4)"

  if [[ "$KEEP_PUBLIC_SSH_EXPLICIT" != "true" ]]; then
    KEEP_PUBLIC_SSH="false"
    log_auto "KEEP_PUBLIC_SSH=false (Tailscale joined)"
  fi
}

write_sshd_dropin() {
  log "Writing SSH hardening drop-in: $SSHD_DROPIN"
  mkdir -p /etc/ssh/sshd_config.d
  cat >"$SSHD_DROPIN" <<EOF
# Managed by vps-hardener — do not edit by hand
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
PubkeyAuthentication yes
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers $DEPLOY_USER
EOF
  sshd -t
}

ensure_deploy_ssh_keys() {
  local keys_file="/home/$DEPLOY_USER/.ssh/authorized_keys"
  local sudo_keys
  sudo_keys="$(sudo_user_authorized_keys_path || true)"

  mkdir -p "/home/$DEPLOY_USER/.ssh"

  if [[ -n "$SSH_PUBLIC_KEY" ]]; then
    echo "$SSH_PUBLIC_KEY" >>"$keys_file"
  fi

  if [[ -n "$SSH_AUTHORIZED_KEYS" ]]; then
    if [[ -f "$SSH_AUTHORIZED_KEYS" ]]; then
      cat "$SSH_AUTHORIZED_KEYS" >>"$keys_file"
    else
      printf '%s\n' "$SSH_AUTHORIZED_KEYS" >>"$keys_file"
    fi
  fi

  if [[ -n "$sudo_keys" ]] && authorized_keys_has_entries "$sudo_keys"; then
    cat "$sudo_keys" >>"$keys_file"
  fi

  if [[ -f /root/.ssh/authorized_keys ]] && [[ ! -s "$keys_file" ]]; then
    cp /root/.ssh/authorized_keys "$keys_file"
  fi

  if [[ -s "$keys_file" ]]; then
    sort -u "$keys_file" -o "$keys_file"
    chmod 600 "$keys_file"
    chown "$DEPLOY_USER:$DEPLOY_USER" "$keys_file"
    return 0
  fi

  echo "WARNING: No SSH keys for $DEPLOY_USER after setup." >&2
  die "Stopping to prevent SSH lockout."
}

configure_firewall() {
  log "Installing and configuring firewall"
  apt install -y ufw

  ufw default deny incoming
  ufw default allow outgoing

  if [[ "$ALLOW_HTTP" == "true" ]]; then
    ufw_allow_once "80/tcp" '(^|/)80/tcp'
  fi
  if [[ "$ALLOW_HTTPS" == "true" ]]; then
    ufw_allow_once "443/tcp" '(^|/)443/tcp'
  fi

  if [[ "$USE_TAILSCALE" == "true" ]]; then
    log "Installing Tailscale"
    install_tailscale
    bootstrap_tailscale

    ufw_allow_once "in on tailscale0 to any port $SSH_PORT proto tcp" \
      "tailscale0.*$SSH_PORT"

    if [[ "$KEEP_PUBLIC_SSH" == "true" ]]; then
      ufw_allow_once "$SSH_PORT/tcp" "(^|/)$SSH_PORT/tcp"
      PUBLIC_SSH_OPEN="true"
      echo "Public SSH remains open."
    elif tailscale_has_ipv4; then
      close_public_ssh_ufw
    else
      ufw_allow_once "$SSH_PORT/tcp" "(^|/)$SSH_PORT/tcp"
      PUBLIC_SSH_OPEN="true"
      echo "WARNING: Tailscale not connected — public SSH left open on port $SSH_PORT."
      echo "Set TAILSCALE_AUTHKEY or run 'sudo tailscale up', then re-run."
    fi
  else
    echo "Tailscale disabled."
    if [[ "$KEEP_PUBLIC_SSH" == "false" ]]; then
      PUBLIC_SSH_OPEN="false"
      local cidr trimmed
      IFS=',' read -ra cidrs <<<"$ALLOW_SSH_FROM"
      for cidr in "${cidrs[@]}"; do
        trimmed="${cidr// /}"
        [[ -z "$trimmed" ]] && continue
        ufw_allow_once "from $trimmed to any port $SSH_PORT proto tcp" \
          "from $trimmed.*$SSH_PORT"
      done
      echo "Public SSH restricted to ALLOW_SSH_FROM CIDRs only."
    else
      ufw_allow_once "$SSH_PORT/tcp" "(^|/)$SSH_PORT/tcp"
      PUBLIC_SSH_OPEN="true"
    fi
  fi

  ufw --force enable
}

install_fail2ban_if_needed() {
  if [[ "$PUBLIC_SSH_OPEN" != "true" ]]; then
    log "Skipping Fail2ban (no public SSH)"
    return 0
  fi
  log "Installing Fail2ban (public SSH is open)"
  apt install -y fail2ban
  cat >/etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
findtime = 10m
bantime = 12h
EOF
  systemctl enable fail2ban
  systemctl restart fail2ban
}

enable_persistent_journal() {
  log "Enabling persistent logs"
  mkdir -p /var/log/journal
  if [[ -f /etc/systemd/journald.conf ]]; then
    if grep -qE '^\s*#?\s*Storage\s*=' /etc/systemd/journald.conf; then
      sed -i -E 's|^\s*#?\s*Storage\s*=.*|Storage=persistent|' /etc/systemd/journald.conf
    else
      printf '\n[Journal]\nStorage=persistent\n' >>/etc/systemd/journald.conf
    fi
  else
    mkdir -p /etc/systemd
    cat >/etc/systemd/journald.conf <<'EOF'
[Journal]
Storage=persistent
EOF
  fi
  systemctl restart systemd-journald
}

print_effective_config() {
  log "Effective configuration"
  echo "  PROFILE=${PROFILE:-<unset>}$([[ "$PROFILE_EXPLICIT" != "true" && -z "$PROFILE" ]] && echo " (default)")"
  echo "  DEPLOY_USER=$DEPLOY_USER"
  echo "  TIMEZONE=$TIMEZONE"
  echo "  SSH_PORT=$SSH_PORT"
  echo "  USE_TAILSCALE=$USE_TAILSCALE"
  echo "  KEEP_PUBLIC_SSH=$KEEP_PUBLIC_SSH"
  echo "  ALLOW_SSH_FROM=${ALLOW_SSH_FROM:-<unset>}"
  echo "  ALLOW_HTTP=$ALLOW_HTTP ALLOW_HTTPS=$ALLOW_HTTPS"
  echo "  PUBLIC_SSH_OPEN=$PUBLIC_SSH_OPEN"
  if [[ -n "$TAILSCALE_AUTHKEY" ]]; then
    echo "  TAILSCALE_AUTHKEY=<set>"
  elif [[ "$TAILSCALE_AUTHKEY_EXPLICIT" == "true" ]]; then
    echo "  TAILSCALE_AUTHKEY=<empty>"
  fi
  if [[ "$ALLOW_SSH_FROM_EXPLICIT" == "true" ]]; then
    echo "  (ALLOW_SSH_FROM set explicitly)"
  fi
  if [[ "$DEPLOY_USER_EXPLICIT" == "true" ]]; then
    echo "  (DEPLOY_USER set explicitly)"
  fi
  if ((${#AUTO_NOTES[@]} > 0)); then
    echo ""
    echo "  Automation applied:"
    local note
    for note in "${AUTO_NOTES[@]}"; do
      echo "    - $note"
    done
  fi
}

# --- main ---
if [[ "$EUID" -ne 0 ]]; then
  die "Run this script with sudo or as root."
fi

apply_defaults
normalize_bools
validate_inputs
require_ssh_credentials

log "Starting VPS hardening"
print_effective_config

export DEBIAN_FRONTEND=noninteractive

log "Updating and upgrading server"
apt update
apt upgrade -y

apt install -y \
  curl wget ca-certificates gnupg lsb-release software-properties-common \
  apt-transport-https htop git unzip jq net-tools dnsutils

if [[ "$INSTALL_MICRO" == "true" ]]; then
  log "Installing micro editor"
  if ! command -v micro >/dev/null 2>&1; then
    TMP_DIR="$(mktemp -d)"
    (cd "$TMP_DIR" && curl -fsSL https://getmic.ro | bash && [[ -f micro ]] && install -m 0755 micro /usr/bin/micro)
    rm -rf "$TMP_DIR"
  fi
else
  echo "Skipping micro install. Set INSTALL_MICRO=true to enable."
fi

if [[ "$INSTALL_SNAP_MICRO" == "true" ]]; then
  log "Installing micro via snap"
  if ! command -v snap >/dev/null 2>&1; then
    apt install -y snapd
    systemctl enable --now snapd
  fi
  if ! snap list micro >/dev/null 2>&1; then
    snap install micro --classic || true
  fi
fi

log "Creating deploy user"
if id "$DEPLOY_USER" >/dev/null 2>&1; then
  echo "User $DEPLOY_USER already exists."
else
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
fi
usermod -aG sudo "$DEPLOY_USER"
ensure_deploy_ssh_keys
chown -R "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
chmod 700 "/home/$DEPLOY_USER/.ssh"
cat >/etc/sudoers.d/90-"$DEPLOY_USER" <<EOF
$DEPLOY_USER ALL=(ALL:ALL) NOPASSWD:ALL
EOF
chmod 440 /etc/sudoers.d/90-"$DEPLOY_USER"

configure_firewall
install_fail2ban_if_needed

log "Installing unattended upgrades"
apt install -y unattended-upgrades apt-listchanges
cat >/etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
dpkg-reconfigure -f noninteractive unattended-upgrades

log "Installing Chrony and setting timezone"
apt install -y chrony
timedatectl set-timezone "$TIMEZONE"
systemctl enable chrony
systemctl restart chrony

log "Applying sysctl hardening"
cat >/etc/sysctl.d/99-vps-hardening.conf <<EOF
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
EOF
sysctl --system >/dev/null

enable_persistent_journal

write_sshd_dropin
log "Reloading SSH"
sshd -t
systemctl reload ssh 2>/dev/null || systemctl reload sshd

log "Hardening completed"
print_effective_config

echo ""
echo "Next steps:"
echo "1. Test: ssh -p $SSH_PORT $DEPLOY_USER@YOUR_SERVER_IP"
echo "2. Test sudo: sudo whoami"
if [[ "$USE_TAILSCALE" == "true" ]]; then
  if ! tailscale_has_ipv4; then
    echo "3. Join Tailscale: sudo tailscale up"
  else
    echo "3. Tailscale IP: $(tailscale ip -4 2>/dev/null || true)"
  fi
fi
echo "4. Check firewall: sudo ufw status verbose"
echo "5. Reboot when ready: sudo reboot"
echo ""
echo "Do not close your current session until deploy SSH login works."
