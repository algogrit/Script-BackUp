# Global rules

These apply in every project and session.

## Writing style

- Never use em dashes (—, U+2014) in prose, comments, code, docs, or any output.
  Use a hyphen, colon, comma, or restructure the sentence instead. Arrows (→) and
  box-drawing separators (─) are different characters and are fine to keep.

## Files

- Never edit, create, or delete files under a `management/tasks/` directory in any
  project. Treat it as read-only-at-most; the user maintains it. Do not include it
  in repo-wide sweeps (for example, em-dash cleanup).

## Background work and waiting

- To wait for a command you started, run it with `run_in_background` and let the
  harness notify you when it exits. Do not start a job and then poll for it in a
  separate shell loop.
- Never wait by grepping the process table for the command's own text. A loop
  spelled `until ! pgrep -f "some-target"; do sleep 30; done` matches its own
  command line, because the pattern is in the loop's `argv`. It then spins
  forever no matter what the real job did. If a process check is genuinely
  needed, match on a captured PID (`kill -0 "$pid"`), or exclude self with
  `pgrep -f pattern | grep -v "^$$\$"`, and confirm the pattern matches only
  what you meant before trusting it.
- **A waiter that is still waiting is not evidence that the work is still
  running.** Those two states look identical from the outside, and one of them
  means the job died. Before reporting something as "in progress", check a
  signal that only the job itself can produce: the log's mtime advancing, new
  output lines, the artifact appearing. If that signal is stale, the job is
  finished or dead, so read its exit status and its log rather than reporting
  progress.
- Report a job's outcome from its exit code and log, never from the fact that a
  wrapper has not returned. Silence is not success.
