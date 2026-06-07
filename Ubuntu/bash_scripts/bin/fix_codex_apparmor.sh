#!/usr/bin/env bash
set -euo pipefail

CODEX_PROFILE_FILE="/etc/apparmor.d/codex-native"
BWRAP_PROFILE_FILE="/etc/apparmor.d/codex-bwrap"
TRACE_LOG="/tmp/codex-apparmor-trace.log"
KEEP_TRACE=0
EXPLICIT_CODEX_BIN=""
declare -a EXPLICIT_BWRAP_PATHS=()

action_user() {
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    printf '%s' "$SUDO_USER"
  else
    id -un
  fi
}

INVOKING_USER="$(action_user)"

log() {
  printf '[fix_codex_apparmor] %s\n' "$*"
}

warn() {
  printf '[fix_codex_apparmor] WARNING: %s\n' "$*" >&2
}

die() {
  printf '[fix_codex_apparmor] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF2'
Usage:
  sudo bash fix_codex_apparmor_complete_v2.sh [--codex-bin PATH] [--bwrap PATH] [--keep-trace]

What it does:
  * Detects the native Codex executable actually used on this machine.
  * Detects the bwrap path(s) Codex executes.
  * Writes targeted AppArmor profiles for the native Codex binary and bwrap.
  * Reloads those profiles and tests `codex sandbox /bin/true`.

Options:
  --codex-bin PATH   Use this Codex executable path instead of searching PATH.
  --bwrap PATH       Add a bwrap path explicitly. You may repeat this option.
  --keep-trace       Keep the strace output at /tmp/codex-apparmor-trace.log.
  -h, --help         Show this help.
EOF2
}

parse_args() {
  while (($#)); do
    case "$1" in
      --codex-bin)
        (($# >= 2)) || die "--codex-bin requires a path"
        EXPLICIT_CODEX_BIN="$2"
        shift 2
        ;;
      --bwrap)
        (($# >= 2)) || die "--bwrap requires a path"
        EXPLICIT_BWRAP_PATHS+=("$2")
        shift 2
        ;;
      --keep-trace)
        KEEP_TRACE=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "Run this script with sudo or as root."
}

run_shell_as_invoking_user() {
  local cmd="$1"
  if [[ "$(id -un)" == "$INVOKING_USER" ]]; then
    bash -lc "$cmd"
  else
    sudo -u "$INVOKING_USER" -H bash -lc "$cmd"
  fi
}

run_cmd_as_invoking_user() {
  if [[ "$(id -un)" == "$INVOKING_USER" ]]; then
    "$@"
  else
    sudo -u "$INVOKING_USER" -H -- "$@"
  fi
}

canonicalize_path() {
  local path="$1"
  if [[ -e "$path" ]]; then
    readlink -f "$path"
  else
    printf '%s\n' "$path"
  fi
}

find_codex_wrapper() {
  local wrapper

  if [[ -n "$EXPLICIT_CODEX_BIN" ]]; then
    wrapper="$(canonicalize_path "$EXPLICIT_CODEX_BIN")"
    [[ -x "$wrapper" ]] || die "--codex-bin path is not executable: $wrapper"
    printf '%s\n' "$wrapper"
    return 0
  fi

  wrapper="$(run_shell_as_invoking_user 'command -v codex 2>/dev/null || true')"
  [[ -n "$wrapper" ]] || die "Could not find 'codex' in ${INVOKING_USER}'s PATH. Re-run with --codex-bin /full/path/to/codex."
  canonicalize_path "$wrapper"
}

trace_codex_execs() {
  local wrapper="$1"
  if ! command -v strace >/dev/null 2>&1; then
    warn "strace is not installed; auto-detection will be more limited."
    return 0
  fi

  rm -f "$TRACE_LOG"
  log "Tracing Codex once to discover the actual executable paths it uses"
  if ! run_cmd_as_invoking_user strace -f -e trace=execve -o "$TRACE_LOG" "$wrapper" sandbox /bin/true >/dev/null 2>&1; then
    true
  fi
}

extract_execve_paths() {
  [[ -f "$TRACE_LOG" ]] || return 0
  sed -n 's/.*execve("\([^"]*\)".*/\1/p' "$TRACE_LOG"
}

search_common_native_codex_paths() {
  local wrapper="$1"
  local wrapper_dir wrapper_parent npm_root
  wrapper_dir="$(dirname "$wrapper")"
  wrapper_parent="$(dirname "$wrapper_dir")"
  npm_root="$(run_shell_as_invoking_user 'npm root -g 2>/dev/null || true')"

  {
    find "$wrapper_dir" -maxdepth 8 -type f -perm -111 -path '*/vendor/*/codex/codex' 2>/dev/null || true
    find "$wrapper_parent" -maxdepth 8 -type f -perm -111 -path '*/vendor/*/codex/codex' 2>/dev/null || true
    if [[ -n "$npm_root" && -d "$npm_root" ]]; then
      find "$npm_root" -maxdepth 8 -type f -perm -111 -path '*/vendor/*/codex/codex' 2>/dev/null || true
    fi
  } | awk '!seen[$0]++'
}

select_native_codex_path() {
  local wrapper="$1"
  local candidate="" path

  if [[ -n "$EXPLICIT_CODEX_BIN" ]]; then
    candidate="$(canonicalize_path "$EXPLICIT_CODEX_BIN")"
    [[ -x "$candidate" ]] || die "--codex-bin path is not executable: $candidate"
    printf '%s\n' "$candidate"
    return 0
  fi

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ -x "$path" ]] || continue
    if [[ "$(basename "$path")" == "codex" && "$path" != "$wrapper" && ( "$path" == *"/vendor/"* || "$path" == *"@openai/codex"* || "$path" == *"unknown-linux"* ) ]]; then
      candidate="$path"
    fi
  done < <(extract_execve_paths)

  if [[ -n "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ -x "$path" ]] || continue
    if [[ "$(basename "$path")" == "codex" && "$path" != "$wrapper" ]]; then
      candidate="$path"
    fi
  done < <(extract_execve_paths)

  if [[ -n "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ -x "$path" ]] || continue
    candidate="$path"
    break
  done < <(search_common_native_codex_paths "$wrapper")

  if [[ -n "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  if [[ -x "$wrapper" && "$(basename "$wrapper")" == "codex" ]]; then
    printf '%s\n' "$wrapper"
    return 0
  fi

  die "Could not determine the native Codex binary path automatically. Re-run with --codex-bin PATH."
}

collect_bwrap_paths() {
  local -a found=()
  local path explicit

  if [[ -x /usr/bin/bwrap ]]; then
    found+=("$(canonicalize_path /usr/bin/bwrap)")
  fi

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ -x "$path" ]] || continue
    if [[ "$(basename "$path")" == "bwrap" ]]; then
      found+=("$(canonicalize_path "$path")")
    fi
  done < <(extract_execve_paths)

  for explicit in "${EXPLICIT_BWRAP_PATHS[@]}"; do
    explicit="$(canonicalize_path "$explicit")"
    [[ -x "$explicit" ]] || die "--bwrap path is not executable: $explicit"
    found+=("$explicit")
  done

  printf '%s\n' "${found[@]}" | awk 'NF && !seen[$0]++'
}

write_codex_profile() {
  local codex_bin="$1"
  log "Writing $CODEX_PROFILE_FILE for $codex_bin"
  cat >"$CODEX_PROFILE_FILE" <<EOF2
abi <abi/4.0>,
include <tunables/global>

@{codex_bin} = $codex_bin

profile codex-native @{codex_bin} flags=(unconfined) {
  userns,
  @{codex_bin} mr,

  include if exists <local/codex-native>
}
EOF2
}

write_bwrap_profile() {
  local -a bwrap_paths=("$@")
  local i=0

  log "Writing $BWRAP_PROFILE_FILE"
  {
    printf 'abi <abi/4.0>,\n'
    printf 'include <tunables/global>\n\n'
    for path in "${bwrap_paths[@]}"; do
      ((++i))
      printf '@{bwrap_bin_%d} = %s\n' "$i" "$path"
    done
    printf '\n'
    i=0
    for path in "${bwrap_paths[@]}"; do
      ((++i))
      cat <<EOF2
profile codex-bwrap-$i @{bwrap_bin_$i} flags=(unconfined) {
  userns,
  @{bwrap_bin_$i} mr,

  include if exists <local/bwrap>
}

EOF2
    done
  } >"$BWRAP_PROFILE_FILE"
}

reload_apparmor() {
  command -v apparmor_parser >/dev/null 2>&1 || die "apparmor_parser is not installed."
  log "Reloading AppArmor profiles"
  apparmor_parser -r "$CODEX_PROFILE_FILE"
  if [[ -f "$BWRAP_PROFILE_FILE" ]]; then
    apparmor_parser -r "$BWRAP_PROFILE_FILE"
  fi
}

show_environment() {
  log "AppArmor status"
  if command -v aa-status >/dev/null 2>&1; then
    aa-status --enabled >/dev/null 2>&1 && aa-status --enabled && true || warn "aa-status reports AppArmor is not enabled"
  else
    warn "aa-status is not installed"
  fi

  log "Relevant sysctls"
  sysctl kernel.apparmor_restrict_unprivileged_userns 2>/dev/null || true
  sysctl kernel.apparmor_restrict_unprivileged_unconfined 2>/dev/null || true
}

verify_codex_sandbox() {
  local wrapper="$1"
  log "Testing Codex sandbox as ${INVOKING_USER}: $wrapper sandbox /bin/true"
  if run_cmd_as_invoking_user "$wrapper" sandbox /bin/true; then
    log "Codex sandbox test succeeded"
  else
    warn "Codex sandbox test still failed"
    warn "If the trace did not reveal the real native binary or bwrap path, re-run with --keep-trace and explicit --codex-bin/--bwrap arguments."
    return 1
  fi
}

print_summary() {
  local wrapper="$1"
  local codex_bin="$2"
  shift 2
  local -a bwrap_paths=("$@")

  cat <<EOF2

Done.

Detected wrapper:
  $wrapper
Detected native Codex binary:
  $codex_bin
Detected bwrap path(s):
$(for p in "${bwrap_paths[@]}"; do printf '  %s\n' "$p"; done)
Installed profiles:
  $CODEX_PROFILE_FILE
$(if [[ -f "$BWRAP_PROFILE_FILE" ]]; then printf "  %s\n" "$BWRAP_PROFILE_FILE"; else printf "  (no bwrap profile written)\n"; fi)

If you want to inspect the generated profiles:
  sudo cat $CODEX_PROFILE_FILE
$(if [[ -f "$BWRAP_PROFILE_FILE" ]]; then printf "  sudo cat %s\n" "$BWRAP_PROFILE_FILE"; fi)
EOF2

  if [[ "$KEEP_TRACE" -eq 1 && -f "$TRACE_LOG" ]]; then
    cat <<EOF2

Trace kept at:
  $TRACE_LOG
EOF2
  fi
}

cleanup() {
  if [[ "$KEEP_TRACE" -ne 1 ]]; then
    rm -f "$TRACE_LOG"
  fi
}

main() {
  parse_args "$@"
  require_root

  local wrapper codex_bin
  local -a bwrap_paths=()

  wrapper="$(find_codex_wrapper)"
  log "Using Codex wrapper: $wrapper"

  trace_codex_execs "$wrapper"
  codex_bin="$(select_native_codex_path "$wrapper")"
  log "Using native Codex binary: $codex_bin"

  mapfile -t bwrap_paths < <(collect_bwrap_paths)

  write_codex_profile "$codex_bin"
  if ((${#bwrap_paths[@]} > 0)); then
    write_bwrap_profile "${bwrap_paths[@]}"
  else
    warn "No bwrap path was detected. Skipping the bwrap profile and installing only the native Codex profile."
    rm -f "$BWRAP_PROFILE_FILE"
  fi
  reload_apparmor
  show_environment
  verify_codex_sandbox "$wrapper"
  print_summary "$wrapper" "$codex_bin" "${bwrap_paths[@]}"
  cleanup
}

main "$@"
