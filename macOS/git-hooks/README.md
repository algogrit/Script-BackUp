# Global git hooks

This directory is wired up as the machine-wide hooks directory:

```sh
git config --global core.hooksPath /Users/gaurav/git-hooks/
```

Every hook here runs in **every** repo on this machine, including repos cloned in
the future and commits made by coding agents.

| Hook            | Purpose                                                       |
| --------------- | ------------------------------------------------------------- |
| `pre-commit`    | Scans staged additions for credentials and debug leftovers.   |
| `commit-msg`    | Scans the commit message.                                     |
| `pre-push`      | Scans the commits being pushed, then hands off to Git LFS.    |
| `post-commit`   | Git LFS boilerplate.                                          |
| `post-checkout` | Git LFS boilerplate.                                          |
| `post-merge`    | Git LFS boilerplate.                                          |

| Library         | Purpose                                                       |
| --------------- | ------------------------------------------------------------- |
| `lib/scan.awk`  | The rule engine. All three scanning hooks share it.           |
| `lib/common.sh` | Shared bash helpers: rendering, prompting, exit codes.        |

## Design posture

Tuned for **recall**. A false positive costs one `pre-commit-allow` comment; a
false negative is unrecoverable, because a pushed secret must be treated as
burned. Where a filter exists it is because it was measured against ~1.16M added
lines of real history, not because it looked tidy.

Current cost on this machine's repos: **~0.17 findings per commit** across 15
repos and 2,771 commits.

## The three layers

`pre-commit` only ever sees the index, which leaves two gaps that better rules
cannot close. All three hooks run the same rules:

1. **`pre-commit`** catches the common case at the cheapest moment.
2. **`commit-msg`** catches a token pasted into the message rather than a file.
3. **`pre-push`** is the backstop: it scans each commit's own patch across the
   range being pushed, so a secret that arrived via `--no-verify`, or predates
   these hooks, is caught before it leaves the machine. It scans per commit
   rather than the net diff, because a secret added and then removed within the
   range is still published.

## Rules

Only lines being **added** are scanned. Deletions, context lines and binary
files are ignored. Any match blocks.

| Rule | Fires on |
| ---- | -------- |
| `debug-leftover` | `console.log`, `console.debug`, `debugger` |
| `secret-assignment` | A secret-ish name assigned a quoted literal: `password = "hunter2"` |
| `secret-assignment-unquoted` | The same names with an unquoted value: `POSTGRES_PASSWORD: nayak`. Skipped in `.go`, `.ts`, `.py`, `.java` and friends, where an unquoted right-hand side is necessarily a variable reference. The skip list is a blocklist, so an unfamiliar file type gets scanned rather than ignored. |
| `high-confidence-key` | An unmistakable credential format: `sk-`/`sk-ant-`/`sk-proj-`, `sk_live_`, `ghp_` and friends, `github_pat_`, `AKIA`/`ASIA`/`AROA`…, `xoxb-`, `AIza`, `ya29.`, `GOCSPX-`, `glpat-`, `npm_`, `SG.`, `shpat_`, `dop_v1_`, `figd_`, `lin_api_`, `sq0atp-`, `pypi-AgEI`, Slack webhook URLs, PEM `PRIVATE KEY` headers, PuTTY key files |
| `credential-in-url` | `scheme://user:pass@host` |
| `sensitive-filename` | The staged path itself: `.env*`, `.envrc`, `.netrc`, `.npmrc`, `.pypirc`, `.pgpass`, `.htpasswd`, `credentials`, `id_rsa`/`id_ed25519`/…, `*.pem|key|p12|pfx|jks|keystore|ppk|kdbx`, `*.tfvars`, `*service-account*.json`, `secrets.{yml,json,toml}` |
| `high-entropy-context` | A random-looking token of 20+ chars on a line that also carries a secret-ish word |
| `high-entropy-value` | A random-looking token of 24+ chars sitting in value position: quoted, or the entire right-hand side of `=` or `:` |

The entropy rules exist because no prefix list can enumerate every credential
format. They are what catches a random password with no recognisable shape.

### What the entropy rules deliberately ignore

Shannon entropy rates a run of distinct characters as maximally random, so a
literal alphabet scores higher than a real key. Thresholds alone are not enough.
These are filtered out:

- lockfiles and generated trees (`*.lock`, `go.sum`, `package-lock.json`,
  `vendor/`, `node_modules/`, `dist/`, `testdata/`, `__snapshots__/`, `*.min.js`)
- `md5`/`shasum` digest listings
- lines over 400 characters (minified, not authored)
- UUIDs, hex-only tokens, and sequential alphabets
- `snake_case` and `SCREAMING_SNAKE` identifiers, so the rule fires on a value
  rather than on the env var name beside it
- shell variable references, filesystem paths, and tokens inside a URL (the
  last only when the line has no secret-ish word, so `?access_token=…` is still
  examined)

## Allowing a single line

Append a `pre-commit-allow` comment (or `pragma: allowlist secret`) to the exact
line, in whatever comment syntax the file uses. Only that line is skipped, and
the exemption is visible in the diff at review time.

```js
const token = "abc123";  // pre-commit-allow
```

```yaml
GF_SECURITY_ADMIN_PASSWORD: "admin"  # pre-commit-allow
```

A `sensitive-filename` finding has no line to attach the marker to, so it is
waived by putting the marker on **any** added line of that file. Files ending in
`.example`, `.sample`, `.template`, `.dist`, `.tmpl` or `.tpl` are exempt from
that rule automatically. Their **contents** are still scanned, so a real key
inside `.env.example` still blocks.

## Bypassing every check

```sh
git commit --no-verify
git push   --no-verify
```

Prefer `pre-commit-allow`. `--no-verify` also disables the Git LFS hooks and
leaves no trace in the diff. Anything smuggled past `pre-commit` this way is
still caught by `pre-push`.

## Output

In an interactive terminal, findings are grouped by file and you are prompted:

```
⛔ pre-commit: 2 issue(s) in staged changes

  src/api/client.ts
       41  secret-assignment           const apiKey = "sk-a…";
       88  debug-leftover              console.log(user.email);

  Allow one line by appending a `pre-commit-allow` comment to it.
  Skip every check for this commit: git commit --no-verify

⚠️  Continue anyway? (y/N):
```

Everywhere else (agents, CI, GUI clients) it prints the standard compiler/lint
shape and blocks, with no prompt to hang on:

```
pre-commit: BLOCKED: 2 finding(s) in staged changes

src/api/client.ts:41: [secret-assignment] const apiKey = "sk-a…";
src/api/client.ts:88: [debug-leftover] console.log(user.email);
```

"Interactive" means stderr is a terminal, `/dev/tty` is openable, and neither
`CLAUDECODE` nor `CI` is set. Secret values are always masked to their first four
characters, so credentials never reach terminal scrollback or an agent
transcript.

## Exit codes

| Code | Meaning                               |
| ---- | ------------------------------------- |
| `0`  | Clean, or the human chose to continue |
| `1`  | Findings, blocked                     |
| `2`  | Internal error (or Git LFS missing)   |

## Notes

The hooks pin the diff format they parse (`core.quotePath=false`,
`diff.noprefix=false`, `diff.mnemonicPrefix=false`, `--no-textconv`,
`--no-ext-diff`) so a repo-local diff setting cannot break file and line
attribution.

`pre-push` buffers its stdin once and feeds the same ref lines to both the scan
and `git lfs pre-push`, since stdin is readable only once. Git LFS's exit code is
preserved. It scans at most 1000 commits per ref and says so explicitly when it
truncates.

Scanning is a single `awk` pass. A 60-file, 30,000-line commit costs ~0.56s.

To test a change to the rules, pipe a diff straight into the engine:

```sh
git diff --cached -U0 | awk -v US=' | ' -f lib/scan.awk
```
