# common.sh: shared helpers for the pre-commit, commit-msg and pre-push hooks.
# Sourced, never executed.
#
# Each driver must set, before calling hook_report:
#   HOOK_NAME     the hook's own name, used in headers
#   HOOK_SUBJECT  what was scanned, e.g. "staged changes"
#   HOOK_UNIT     the thing being blocked, e.g. "commit"
#   HOOK_BYPASS   the command that skips every check, e.g. "git commit --no-verify"
#   HOOK_HINT     one line of advice for the interactive output
#   HOOK_FIXES    array of remediation options, rendered as a numbered list
#
# HOOK_HINT and HOOK_FIXES are per-hook because the fix differs by hook: a
# staged file can be edited and re-staged, a commit message cannot carry a
# suppression marker without storing it in history, and a finding in an
# already-created commit needs a history rewrite.

HOOK_LIB_DIR=${HOOK_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
SCAN_AWK="$HOOK_LIB_DIR/scan.awk"
US=$'\x1f'

# Config overrides pin the diff format so the parser cannot be broken by a
# repo-local or global diff setting: real a/ b/ prefixes, unquoted paths, no
# textconv or external differ.
hook_git_diff_opts=(
  -c core.quotePath=false
  -c diff.noprefix=false
  -c diff.mnemonicPrefix=false
)

# scan_stream <awk-args...> : reads a diff on stdin, writes findings on stdout.
scan_stream() {
  LC_ALL=C awk -v US="$US" "$@" -f "$SCAN_AWK"
}

# hook_interactive : true only when a human can both see the prompt and answer
# it. The env checks matter because an agent's shell can have /dev/tty open
# while nobody is there to type, and a hook that hangs is worse than one that
# blocks.
hook_interactive() {
  [ -z "${CLAUDECODE:-}" ] || return 1
  [ -z "${CI:-}" ] || return 1
  [ -t 2 ] || return 1
  (: < /dev/tty) 2>/dev/null || return 1
  return 0
}

# hook_render_human <count> <findings> : grouped, colourised, by file.
hook_render_human() {
  local count=$1 findings=$2 prev= file line rule text
  local R=$'\033[31m' Y=$'\033[33m' B=$'\033[1m' D=$'\033[2m' Z=$'\033[0m'

  printf '\n%s⛔ %s: %s issue(s) in %s%s\n\n' "$R$B" "$HOOK_NAME" "$count" "$HOOK_SUBJECT" "$Z"
  while IFS="$US" read -r file line rule text; do
    if [ "$file" != "$prev" ]; then
      printf '  %s%s%s\n' "$B" "$file" "$Z"
      prev=$file
    fi
    if [ "$line" = "0" ]; then
      printf '    %s    -%s  %s%-26s%s  %s\n' "$D" "$Z" "$Y" "$rule" "$Z" "$text"
    else
      printf '    %s%5s%s  %s%-26s%s  %s\n' "$D" "$line" "$Z" "$Y" "$rule" "$Z" "$text"
    fi
  done <<< "$findings"

  printf '\n  %s%s%s\n' "$D" "$HOOK_HINT" "$Z"
  printf '  %sSkip every check for this %s: %s%s\n\n' "$D" "$HOOK_UNIT" "$HOOK_BYPASS" "$Z"
}

# hook_render_agent <count> <findings> : `file:line: [rule] text` is the standard
# compiler/lint shape, so editors and agents parse it without extra work.
hook_render_agent() {
  local count=$1 findings=$2 file line rule text
  printf '\n%s: BLOCKED: %s finding(s) in %s\n\n' "$HOOK_NAME" "$count" "$HOOK_SUBJECT"
  while IFS="$US" read -r file line rule text; do
    if [ "$line" = "0" ]; then
      printf '%s: [%s] %s\n' "$file" "$rule" "$text"
    else
      printf '%s:%s: [%s] %s\n' "$file" "$line" "$rule" "$text"
    fi
  done <<< "$findings"

  # Remediation is per-hook: what resolves a staged-file finding cannot resolve
  # one in a commit message or in an already-published commit.
  printf '\nHow to resolve (pick one):\n'
  local i=1 fix
  for fix in "${HOOK_FIXES[@]}"; do
    printf '  %d. %s\n' "$i" "$fix"
    i=$((i + 1))
  done
  [ -n "${HOOK_NOTE:-}" ] && printf '\n%s\n' "$HOOK_NOTE"

  cat <<EOF

Secret values above are masked to their first 4 characters.
Rules: debug-leftover, secret-assignment, secret-assignment-unquoted,
       high-confidence-key, credential-in-url, sensitive-filename,
       high-entropy-context, high-entropy-value
EOF
}

# hook_report <findings> : renders, prompts if interactive, returns 0 to proceed
# and 1 to block.
hook_report() {
  local findings=$1 count yn
  [ -n "$findings" ] || return 0
  count=$(printf '%s\n' "$findings" | wc -l | tr -d ' ')

  if hook_interactive; then
    hook_render_human "$count" "$findings"
    read -r -p "⚠️  Continue anyway? (y/N): " yn < /dev/tty
    yn=${yn%$'\r'}   # some terminals deliver CR; treat "y" and "y<CR>" alike
    case "$yn" in
      [Yy]|[Yy][Ee][Ss]) return 0 ;;
      *) printf '\nAborted.\n'; return 1 ;;
    esac
  fi

  hook_render_agent "$count" "$findings"
  return 1
}
