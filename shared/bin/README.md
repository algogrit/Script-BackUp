# shared/bin

OS-agnostic helpers. Unlike `macOS/tool-sync/` and `Ubuntu/tool-sync/`, these live outside the
per-OS directories, so `update_scripts.sh`'s `rm -vr *` cannot touch them and there is only ever one
copy to maintain.

## ai-config-sync.sh

Compares and converges Claude Code + Codex config across the macOS and Ubuntu machines.

```sh
./shared/bin/ai-config-sync.sh diff            # what differs between the two OS trees
./shared/bin/ai-config-sync.sh diff -v         # ...with the actual diff bodies
./shared/bin/ai-config-sync.sh adopt --dry-run # what this machine would pull from the other
./shared/bin/ai-config-sync.sh adopt           # pull the other OS's portable config into live ~
```

Each OS still owns its own backup tree (`macOS/Claude`, `Ubuntu/Codex`, ...), written by that OS's
`update_scripts.sh`. This tool sits on top and answers "what has the other machine got that I
haven't?".

Home paths are normalised (`/Users/<user>` and `/home/<user>` → `__AI_HOME__`) before comparing, so
identical config on two machines compares equal instead of drowning the diff in path noise. On
`adopt` they are rewritten to the local `$HOME`.

**Portable** (compared, and synced by `adopt`): Claude `CLAUDE.md`, `settings.json`,
`keybindings.json`, `agents/`, `commands/`, `skills/`, `hooks/`; Codex `AGENTS.md`, `rules/`,
`prompts/`, `skills/`.

**Per-OS** (compared and reported, never synced): Codex `config.toml` and Claude
`plugins/*.json`. These embed absolute install paths, per-machine project trust lists, and OS-only
keys (Codex's `notify` points at a macOS `.app`), so copying them across would produce a config that
references paths that do not exist. `diff` still reports them, so drift stays visible.

`adopt` writes to the **live** `~/.claude` / `~/.codex` (saving a timestamped `.pre-adopt.<stamp>`
copy of anything it overwrites), not to the repo. Run this OS's `update_scripts.sh` afterwards to
record the adopted files into its tree. That is the convergence loop:

```
machine A: update_scripts.sh   ->  A's tree  ->  git push
machine B: git pull  ->  ai-config-sync.sh adopt  ->  live ~  ->  update_scripts.sh  ->  B's tree
```
