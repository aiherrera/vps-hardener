#!/usr/bin/env bash
# Testable helpers mirrored from hardener.sh (keep in sync when changing logic).

normalize_bool() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

get_ssh_client_ip() {
  local client="${SSH_CLIENT:-}"
  if [[ -z "$client" && -n "${SSH_CONNECTION:-}" ]]; then
    client="${SSH_CONNECTION%% *}"
  fi
  echo "${client%%:*}"
}

authorized_keys_has_entries() {
  local file="$1"
  [[ -f "$file" ]] && grep -qvE '^\s*#|^\s*$' "$file" 2>/dev/null
}
