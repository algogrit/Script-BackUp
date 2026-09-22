# lib/env.sh: dynamic platform & Homebrew prefix detection across Apple Silicon, Intel & Linux.
# Sourced by git hooks, POSIX sh compatible.

detect_brew_prefix() {
  if [ -n "${HOMEBREW_PREFIX:-}" ] && [ -d "$HOMEBREW_PREFIX/bin" ]; then
    echo "$HOMEBREW_PREFIX"
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    _brew_bin=$(command -v brew)
    echo "${_brew_bin%/bin/brew}"
    return 0
  fi
  case "$(uname -s 2>/dev/null):$(uname -m 2>/dev/null)" in
    Darwin:arm64)
      [ -x /opt/homebrew/bin/brew ] && { echo "/opt/homebrew"; return 0; }
      ;;
    Darwin:x86_64)
      [ -x /usr/local/bin/brew ] && { echo "/usr/local"; return 0; }
      ;;
    Linux:*)
      [ -x /home/linuxbrew/.linuxbrew/bin/brew ] && { echo "/home/linuxbrew/.linuxbrew"; return 0; }
      ;;
  esac
  for _prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
    if [ -x "$_prefix/bin/brew" ] || [ -x "$_prefix/bin/git-lfs" ]; then
      echo "$_prefix"
      return 0
    fi
  done
  return 1
}

# Ensure the detected prefix/bin is on PATH
_detected_prefix=$(detect_brew_prefix 2>/dev/null)
if [ -n "$_detected_prefix" ]; then
  case ":$PATH:" in
    *:"$_detected_prefix/bin":*) ;;
    *) PATH="$_detected_prefix/bin:$PATH"; export PATH ;;
  esac
fi
unset _detected_prefix _brew_bin _prefix

# Check if the repository actually configures or tracks Git LFS files
repo_uses_lfs() {
  [ -f .lfsconfig ] && return 0
  [ -f .gitattributes ] && grep -q 'filter=lfs' .gitattributes 2>/dev/null && return 0
  git config --local --get-regexp '^filter\.lfs\.' >/dev/null 2>&1 && return 0
  return 1
}

# Safely run a git-lfs hook without failing on non-LFS repos
run_lfs_hook() {
  _hook_name="$1"
  shift

  if command -v git-lfs >/dev/null 2>&1; then
    exec git lfs "$_hook_name" "$@"
  fi

  if repo_uses_lfs; then
    printf >&2 "\n%s\n\n" "This repository is configured for Git LFS but 'git-lfs' was not found on your path. If you no longer wish to use Git LFS, remove this hook by deleting the '$_hook_name' file in the hooks directory (set by 'core.hookspath'; usually '.git/hooks')."
    exit 2
  fi

  exit 0
}
