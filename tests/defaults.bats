#!/usr/bin/env bats

# Unit-style tests for helper logic extracted from hardener.sh.
# Run: bats tests/defaults.bats

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/tests/lib/helpers.sh"
}

@test "normalize_bool lowercases values" {
  [[ "$(normalize_bool TRUE)" == "true" ]]
  [[ "$(normalize_bool False)" == "false" ]]
}

@test "get_ssh_client_ip parses SSH_CLIENT" {
  SSH_CLIENT="203.0.113.10 54321 22"
  [[ "$(get_ssh_client_ip)" == "203.0.113.10" ]]
}

@test "get_ssh_client_ip parses SSH_CONNECTION" {
  unset SSH_CLIENT
  SSH_CONNECTION="198.51.100.5 12345 10.0.0.1 22"
  [[ "$(get_ssh_client_ip)" == "198.51.100.5" ]]
}

@test "authorized_keys_has_entries rejects empty file" {
  local f="$BATS_TEST_TMPDIR/authorized_keys"
  : >"$f"
  ! authorized_keys_has_entries "$f"
}

@test "authorized_keys_has_entries accepts real key line" {
  local f="$BATS_TEST_TMPDIR/authorized_keys"
  echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI test' >"$f"
  authorized_keys_has_entries "$f"
}
