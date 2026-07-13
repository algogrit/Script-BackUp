#!/usr/bin/env bash
#
# Compare / converge Claude Code + Codex config across the macOS and Ubuntu machines.
#
#   ./ai-config-sync.sh diff [-v]           # what differs between the two OS trees
#   ./ai-config-sync.sh adopt [--dry-run]   # pull the other OS's portable config into live ~
#
# Each OS keeps its own backup tree (macOS/Claude, Ubuntu/Claude, ...) written by that OS's
# update_scripts.sh. This tool sits on top of those trees and answers "what has the other machine
# got that I haven't?", then lets this machine adopt it.
#
# Home paths are normalised before comparing (/Users/<u> and /home/<u> -> __AI_HOME__) so the same
# config on two machines compares equal instead of drowning the diff in path noise. On adopt they
# are rewritten to the local $HOME.
#
# config.toml and the Claude plugins/ jsons are deliberately NOT portable: they embed absolute
# install paths, per-machine project trust lists, and OS-only keys (e.g. Codex's macOS `notify`
# path to a .app). They are reported by `diff` so drift is visible, but `adopt` never touches them.
#
# After adopting, run this OS's update_scripts.sh to record the adopted files into its tree.

set -euo pipefail
shopt -s nullglob

MODE="${1:-diff}"
shift || true

VERBOSE=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        -v|--verbose) VERBOSE=1 ;;
        -n|--dry-run) DRY_RUN=1 ;;
        *) echo "!! unknown option: $arg" >&2; exit 1 ;;
    esac
done

HOME_TOKEN="__AI_HOME__"

# ---------------------------------------------------------------------------
# Locate the repo (CWD-independent), and this OS's tree vs the other one.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    :
else
    REPO_ROOT="$SCRIPT_DIR"
    while [ "$REPO_ROOT" != "/" ] && [ ! -d "$REPO_ROOT/.git" ]; do
        REPO_ROOT="$(dirname "$REPO_ROOT")"
    done
    [ -d "$REPO_ROOT/.git" ] || REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

case "$(uname -s)" in
    Darwin) THIS_OS="macOS"; OTHER_OS="Ubuntu" ;;
    *)      THIS_OS="Ubuntu"; OTHER_OS="macOS" ;;
esac
THIS_TREE="$REPO_ROOT/$THIS_OS"
OTHER_TREE="$REPO_ROOT/$OTHER_OS"

# ---------------------------------------------------------------------------
# What travels between machines, and what does not.
#   <tool>|<relative path>   -- tool is the live-dir key (claude / codex)
# ---------------------------------------------------------------------------
PORTABLE=(
    "claude|CLAUDE.md"
    "claude|settings.json"
    "claude|keybindings.json"
    "claude|agents"
    "claude|commands"
    "claude|skills"
    "claude|hooks"
    "codex|AGENTS.md"
    "codex|rules"
    "codex|prompts"
    "codex|skills"
)

# Compared and reported, never synced.
PER_OS=(
    "codex|config.toml"
    "claude|plugins/known_marketplaces.json"
    "claude|plugins/installed_plugins.json"
)

# Map a tool key to its repo sub-dir and its live dir.
repo_dir()  { case "$1" in claude) echo "Claude" ;; codex) echo "Codex" ;; esac; }
live_dir()  { case "$1" in claude) echo "$HOME/.claude" ;; codex) echo "$HOME/.codex" ;; esac; }

# ---------------------------------------------------------------------------
# Path normalisation. Only ever rewrite text config, never binaries.
# ---------------------------------------------------------------------------
TEXT_EXTS=(-name '*.md' -o -name '*.json' -o -name '*.toml' -o -name '*.rules' -o -name '*.sh' -o -name '*.yaml' -o -name '*.yml')

# Rewrite every home path (any user, either OS) to $2 across the text files under $1.
# Note the '#' sed delimiter: '|' is taken by the (Users|home) alternation.
rewrite_home() {
    local target="$1" to="$2" f esc
    esc="$(printf '%s' "$to" | sed -e 's/[#&\\]/\\&/g')"
    if [ -f "$target" ]; then
        sed -i.tmp -E "s#/(Users|home)/[^/\"[:space:]]+#$esc#g" "$target" && rm -f "$target.tmp"
        return
    fi
    while IFS= read -r -d '' f; do
        sed -i.tmp -E "s#/(Users|home)/[^/\"[:space:]]+#$esc#g" "$f" && rm -f "$f.tmp"
    done < <(find "$target" \( "${TEXT_EXTS[@]}" \) -type f -print0 2>/dev/null)
}

# Copy $1 (file or dir) to a scratch location and normalise its home paths for comparison.
normalised_copy() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
    rewrite_home "$dest" "$HOME_TOKEN"
}

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/ai-config-sync.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT

# An empty dir carries no config (e.g. Codex/skills once .system is excluded); treat it as absent
# so it does not read as drift.
has_content() {
    [ -f "$1" ] && return 0
    [ -d "$1" ] && [ -n "$(find "$1" -type f -print -quit 2>/dev/null)" ]
}

# Compare $1 (this tree) against $2 (other tree), ignoring home-path differences.
# Echoes one of: same | differs | only-this | only-other | absent
compare_item() {
    local a="$1" b="$2"
    has_content "$a" || a=""
    has_content "$b" || b=""
    if [ -z "$a" ] && [ -z "$b" ]; then echo "absent"; return; fi
    if [ -z "$b" ]; then echo "only-this"; return; fi
    if [ -z "$a" ]; then echo "only-other"; return; fi

    rm -rf "$SCRATCH/a" "$SCRATCH/b"
    normalised_copy "$a" "$SCRATCH/a"
    normalised_copy "$b" "$SCRATCH/b"
    if diff -r -q "$SCRATCH/a" "$SCRATCH/b" >/dev/null 2>&1; then echo "same"; else echo "differs"; fi
}

show_diff() {
    local a="$1" b="$2"
    rm -rf "$SCRATCH/a" "$SCRATCH/b"
    [ -e "$a" ] && normalised_copy "$a" "$SCRATCH/a" || mkdir -p "$SCRATCH/a"
    [ -e "$b" ] && normalised_copy "$b" "$SCRATCH/b" || mkdir -p "$SCRATCH/b"
    diff -r -u --label "$THIS_OS" --label "$OTHER_OS" "$SCRATCH/a" "$SCRATCH/b" | sed 's/^/    /' || true
}

# ---------------------------------------------------------------------------
# diff:  this OS's tree  vs  the other OS's tree
# ---------------------------------------------------------------------------
do_diff() {
    echo "=== AI config diff ==="
    echo "This : $THIS_TREE"
    echo "Other: $OTHER_TREE"
    echo "(home paths normalised to $HOME_TOKEN before comparing)"
    echo

    local entry tool rel a b status
    echo "-- portable (adopt can sync these) --"
    for entry in "${PORTABLE[@]}"; do
        tool="${entry%%|*}"; rel="${entry#*|}"
        a="$THIS_TREE/$(repo_dir "$tool")/$rel"
        b="$OTHER_TREE/$(repo_dir "$tool")/$rel"
        status="$(compare_item "$a" "$b")"
        [ "$status" = "absent" ] && continue
        case "$status" in
            same)       printf '   same         %s/%s\n' "$(repo_dir "$tool")" "$rel" ;;
            differs)    printf '   DIFFERS      %s/%s\n' "$(repo_dir "$tool")" "$rel" ;;
            only-this)  printf '   only %-7s %s/%s\n' "$THIS_OS" "$(repo_dir "$tool")" "$rel" ;;
            only-other) printf '   only %-7s %s/%s   <- adoptable\n' "$OTHER_OS" "$(repo_dir "$tool")" "$rel" ;;
        esac
        if [ "$VERBOSE" -eq 1 ] && [ "$status" = "differs" ]; then show_diff "$a" "$b"; fi
    done

    echo
    echo "-- per-OS (reported only, never synced) --"
    for entry in "${PER_OS[@]}"; do
        tool="${entry%%|*}"; rel="${entry#*|}"
        a="$THIS_TREE/$(repo_dir "$tool")/$rel"
        b="$OTHER_TREE/$(repo_dir "$tool")/$rel"
        status="$(compare_item "$a" "$b")"
        [ "$status" = "absent" ] && continue
        printf '   %-12s %s/%s\n' "$status" "$(repo_dir "$tool")" "$rel"
        if [ "$VERBOSE" -eq 1 ] && [ "$status" = "differs" ]; then show_diff "$a" "$b"; fi
    done
    echo
    echo "Run 'adopt' to pull the portable differences into this machine's live config."
}

# ---------------------------------------------------------------------------
# adopt:  other OS's tree  ->  live ~/.claude, ~/.codex (re-localised)
# ---------------------------------------------------------------------------
do_adopt() {
    if [ ! -d "$OTHER_TREE" ]; then
        echo "!! No $OTHER_OS tree at $OTHER_TREE" >&2
        exit 1
    fi

    echo "=== AI config adopt ==="
    echo "From: $OTHER_TREE  ($OTHER_OS)"
    echo "Into: live ~/.claude and ~/.codex"
    [ "$DRY_RUN" -eq 1 ] && echo "(dry run - nothing will be written)"
    echo

    local stamp entry tool rel src this dest status adopted=0
    stamp="$(date +%Y%m%d-%H%M%S)"

    for entry in "${PORTABLE[@]}"; do
        tool="${entry%%|*}"; rel="${entry#*|}"
        src="$OTHER_TREE/$(repo_dir "$tool")/$rel"
        this="$THIS_TREE/$(repo_dir "$tool")/$rel"
        has_content "$src" || continue

        status="$(compare_item "$this" "$src")"
        if [ "$status" = "same" ]; then
            printf '   in sync      %s/%s\n' "$(repo_dir "$tool")" "$rel"
            continue
        fi

        dest="$(live_dir "$tool")/$rel"
        printf '   ADOPT        %s/%s  ->  %s\n' "$(repo_dir "$tool")" "$rel" "$dest"
        adopted=$((adopted + 1))
        [ "$DRY_RUN" -eq 1 ] && continue

        mkdir -p "$(dirname "$dest")"
        if [ -e "$dest" ]; then
            cp -a "$dest" "$dest.pre-adopt.$stamp"
            printf '                (saved previous to %s)\n' "$dest.pre-adopt.$stamp"
        fi
        rm -rf "${dest:?}"
        cp -a "$src" "$dest"
        rewrite_home "$dest" "$HOME"   # re-localise the other machine's home paths
    done

    echo
    if [ "$adopted" -eq 0 ]; then
        echo "Nothing to adopt - this machine already matches $OTHER_OS."
    elif [ "$DRY_RUN" -eq 1 ]; then
        echo "$adopted item(s) would be adopted. Re-run without --dry-run to apply."
    else
        echo "$adopted item(s) adopted. Now run ./update_scripts.sh from $THIS_OS/ to record them."
    fi
}

case "$MODE" in
    diff)  do_diff  ;;
    adopt) do_adopt ;;
    *) echo "Usage: $0 {diff [-v] | adopt [--dry-run]}" >&2; exit 1 ;;
esac
