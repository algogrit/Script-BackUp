# scan.awk: the rule engine behind the pre-commit, commit-msg and pre-push hooks.
#
# Reads a unified diff (-U0, real a/ b/ prefixes) on stdin and writes one record
# per finding:
#
#     <file> US <line> US <rule> US <display text>
#
# where US is \x1f, passed in via -v US=. Line 0 means a file-level finding.
# Secret values in the display text are masked to their first 4 characters.
#
# Tuned for recall: a false positive costs one `pre-commit-allow` comment, a
# false negative is unrecoverable. Every filter here exists because it was
# measured against ~1.16M added lines of real history, not because it felt tidy.
#
# -v MSGMODE=1 scans a commit message instead of a diff: every input line is
# treated as added content, and git's `#` comment lines are skipped.

BEGIN {
  # ---- names suggesting the value beside them is a credential ---------------
  KW_STRONG = "(password|passwd|secret|api[-_. ]?key|apikey|access[-_]?token|auth[-_]?token|refresh[-_]?token|bearer[-_]?token|private[-_]?key|client[-_]?secret|credentials?)"

  # Looser set, used only to give entropy a context signal.
  KW_CONTEXT = KW_STRONG "|token|bearer|authorization|passphrase|signature|session[-_]?id"

  OP = "[\"']?[ \t]*(:=|=>|[:=])[ \t]*"
  ASSIGN_QUOTED   = KW_STRONG OP "[\"'][^\"']{4,}[\"']"
  ASSIGN_UNQUOTED = KW_STRONG OP "[^ \t\"';,)}]"

  # Structural placeholders only, and only when one IS the whole value. Word
  # based exclusions (example/dummy/sample/changeme/...) were removed on
  # purpose: they waved through a real secret whenever the line happened to
  # mention the word elsewhere.
  # A plain variable reference only. `${VAR:-realdefault}` carries a literal
  # default and must NOT be waived, so the brace form is deliberately narrow.
  PLACEHOLDER_ONLY = "^([$][{][A-Za-z_][A-Za-z0-9_]*[}]|[$][A-Za-z_][A-Za-z0-9_]*|[$][(][^)]*[)]|<[^>]*>)$"

  # A value that is plainly code rather than a literal.
  CODEVAL = "^([$]|[{]|[&]|[*]|null|nil|none|true|false|[[]|[(])|[=]{2}|[!][=]|^[a-z_]+[.][a-zA-Z_]|^[A-Za-z_][A-Za-z0-9_]*[(]"

  # Languages where an unquoted right-hand side is necessarily a variable
  # reference, never a literal secret. Blocklist polarity on purpose: a file
  # type nobody anticipated gets scanned rather than silently skipped.
  CODEEXT = "[.](go|ts|tsx|js|jsx|mjs|cjs|py|java|rb|rs|c|cc|cpp|cxx|h|hpp|cs|php|swift|kt|kts|scala|clj|cljs|ex|exs|erl|el|lua|pl|pm|vim|m|mm|dart|hs|ml|r|jl)$"

  # ---- credential formats distinctive enough to flag with no context -------
  KEYS = "sk-[A-Za-z0-9]{32,}" \
    "|sk-(ant|proj)-[A-Za-z0-9_-]{24,}" \
    "|sk_(live|test)_[A-Za-z0-9]{16,}|rk_live_[A-Za-z0-9]{16,}" \
    "|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}" \
    "|A(KIA|SIA|GPA|IDA|ROA|IPA|NPA|NVA|SCA)[0-9A-Z]{16}" \
    "|xox[baprse]-[A-Za-z0-9-]{10,}" \
    "|hooks[.]slack[.]com/services/[A-Za-z0-9/]{20,}" \
    "|AIza[0-9A-Za-z_-]{35}|ya29[.][A-Za-z0-9_-]{20,}|GOCSPX-[A-Za-z0-9_-]{20,}" \
    "|glp(at|tt)-[A-Za-z0-9_-]{20}" \
    "|npm_[A-Za-z0-9]{36}" \
    "|SG[.][A-Za-z0-9_-]{22}[.][A-Za-z0-9_-]{43}" \
    "|shp(at|ss|ca|pa)_[a-f0-9]{32}" \
    "|do[op]_v1_[a-f0-9]{64}" \
    "|figd_[A-Za-z0-9_-]{40}|lin_api_[A-Za-z0-9]{40}" \
    "|sq0(atp|csp)-[A-Za-z0-9_-]{22,}" \
    "|pypi-AgEIcHlwaS5vcmc[A-Za-z0-9_-]{50,}" \
    "|-----BEGIN [A-Z ]*PRIVATE KEY-----|PuTTY-User-Key-File"

  # scheme://user:pass@host
  URLCRED = "[a-zA-Z][a-zA-Z0-9+.-]*://[^/ \t:@\"']+:[^/ \t@\"']+@"

  # ---- whole-file risk -----------------------------------------------------
  SENSITIVE_NAME = "(^|/)([.]env|[.]envrc|[.]netrc|[.]npmrc|[.]pypirc|[.]pgpass|[.]htpasswd|credentials|id_rsa|id_dsa|id_ecdsa|id_ed25519)$" \
    "|(^|/)[.]env[.][^/]*$" \
    "|[.](pem|p12|pfx|jks|keystore|ppk|kdbx|asc)$" \
    "|(^|/)[^/]*[.]key$" \
    "|[.]tfvars$" \
    "|(^|/)[^/]*service[-_]account[^/]*[.]json$" \
    "|(^|/)secrets?[.](ya?ml|json|toml)$"

  # Templates are committed on purpose. Their contents are still scanned by
  # every other rule, so exempting the name costs no recall.
  TEMPLATE_NAME = "[.](example|sample|template|dist|tmpl|tpl)$"

  # ---- entropy filters -----------------------------------------------------
  GENERATED = "[.](lock|sum|snap|map|svg|pb|bin|ipynb|pdf|woff2?|ttf|eot|ico|png|jpe?g|gif|mp4|zip|gz)$" \
    "|[.]min[.](js|css)$" \
    "|(^|/)(package-lock[.]json|yarn[.]lock|pnpm-lock[.]yaml|go[.]sum|cargo[.]lock|poetry[.]lock|gemfile[.]lock|composer[.]lock|pipfile[.]lock|flake[.]lock)$" \
    "|(^|/)(vendor|node_modules|dist|build|elpa|third[-_]party|testdata|__snapshots__|fixtures)/"

  UUID    = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
  HEXONLY = "^[0-9a-f]+$|^[0-9A-F]+$"
  # snake_case or SCREAMING_SNAKE is an identifier, not a credential. Without
  # this the rules fire on the env var NAME (VYUHA_MCP_AUTH_TOKEN) rather than
  # on any value, which was the largest source of noise in the corpus replay.
  IDENTIFIER = "^[A-Za-z][A-Za-z0-9]*(_[A-Za-z0-9]+)+$"
  # Shannon entropy rates a run of distinct characters as maximally random, so a
  # literal alphabet outscores a real key. Reject those shapes explicitly.
  SEQUENTIAL = "0123456789|abcdefghij|ABCDEFGHIJ|qwerty|QWERTY"

  ALLOW = "pre-commit-allow|pragma:[ \t]*allowlist[ \t]+secret"

  ENT_CONTEXT_MIN = 3.6; ENT_CONTEXT_LEN = 20
  ENT_VALUE_MIN   = 4.2; ENT_VALUE_LEN   = 24
  MAXLEN   = 120
  LONGLINE = 400   # beyond this a line is minified, not authored
  MAXTOKENS = 40   # bound the entropy work per line

  if (MSGMODE) { file = "COMMIT_MSG"; inhunk = 1; lineno = 1 }
}

# ---------------------------------------------------------------------------
# Commit message mode: every line is content.
# ---------------------------------------------------------------------------
MSGMODE {
  if ($0 !~ /^#/) scan_line($0, file, lineno)
  lineno++
  next
}

# ---------------------------------------------------------------------------
# Diff mode. Header lines are recognised only before the first hunk, so an added
# line such as `++i;` is never mistaken for a `+++` header.
# ---------------------------------------------------------------------------
/^diff --git / { file = ""; inhunk = 0; next }

!inhunk && /^\+\+\+ / {
  if ($0 ~ /^\+\+\+ \/dev\/null/) {
    file = ""
  } else {
    file = substr($0, 7)      # strip "+++ b/"
    sub(/\t.*$/, "", file)    # git appends a tab when the path contains spaces
    check_filename(file)
  }
  next
}

/^@@ / {
  inhunk = 1
  if (match($0, /\+[0-9]+/)) lineno = substr($0, RSTART + 1, RLENGTH - 1) + 0
  next
}

inhunk && /^\+/ {
  line = substr($0, 2)
  sub(/\r$/, "", line)
  n = lineno++
  if (file != "") scan_line(line, file, n)
  next
}

# Deletions and "\ No newline at end of file" do not advance the new-file counter.
{ next }

# ---------------------------------------------------------------------------

function scan_line(line, f, n,   low, lf) {
  low = tolower(line)
  # The marker waives this line, and any file-level finding for its file.
  # Diff mode only: in a commit message the marker would be stored in history
  # permanently, so message mode ignores it and `--no-verify` is the only bypass.
  if (!MSGMODE && low ~ ALLOW) { allowed[f] = 1; return }
  lf = tolower(f)

  if (line ~ /console\.(log|debug)/ || line ~ /(^|[^A-Za-z0-9_.])debugger[ \t]*;?[ \t]*$/)
    emit(f, n, "debug-leftover", line)

  if (line ~ KEYS)    { emit(f, n, "high-confidence-key", mask_key(line)); return }
  if (line ~ URLCRED) { emit(f, n, "credential-in-url", mask_url(line));   return }

  if (match(low, ASSIGN_QUOTED)) {
    if (check_assign(f, n, line, "secret-assignment")) return
  } else if (lf !~ CODEEXT && match(low, ASSIGN_UNQUOTED)) {
    if (check_assign(f, n, line, "secret-assignment-unquoted")) return
  }

  check_entropy(f, n, line, lf, low)
}

# Uses RSTART/RLENGTH from the caller's match(). Returns 1 if it emitted.
function check_assign(f, n, line, rule,   pre, reg, post, val, q, v) {
  pre  = substr(line, 1, RSTART - 1)
  reg  = substr(line, RSTART, RLENGTH)
  post = substr(line, RSTART + RLENGTH)

  if (rule == "secret-assignment") {
    if (match(reg, /["'][^"']+["']$/)) {
      q = substr(reg, RSTART, 1)
      v = substr(reg, RSTART + 1, RLENGTH - 2)
      if (v ~ PLACEHOLDER_ONLY) return 0
      reg = substr(reg, 1, RSTART - 1) q substr(v, 1, 4) "…" q
    }
    emit(f, n, rule, pre reg post)
    return 1
  }

  # Unquoted: the matched region ends at the FIRST value character, so the real
  # value is that character plus the rest of the line.
  val = substr(reg, length(reg)) post
  sub(/[ \t]*(#|\/\/).*$/, "", val)   # trailing comment is not part of the value
  sub(/[ \t]+$/, "", val)
  if (val == "") return 0
  if (tolower(val) ~ CODEVAL) return 0
  if (val ~ PLACEHOLDER_ONLY) return 0
  emit(f, n, rule, mask_tail(line, val))
  return 1
}

function check_entropy(f, n, line, lf, low,   rest, t, seen, ctx, e, prevch, nextch, preword) {
  if (length(line) > LONGLINE) return
  # Entropy is meaningless on machine-generated content, and this holds even
  # when a keyword appears: the python package `tiktoken` contains "token" and
  # dragged every uv.lock URL into scope. The prefix, assignment and URL rules
  # do not consult GENERATED, so a real secret in a lockfile is still caught.
  if (lf ~ GENERATED) return
  # Standard md5/shasum output: "MD5 (path) = <hex>". Generated, and the path
  # often contains a word like `hash_password`.
  if (line ~ /^[ \t]*(MD5|SHA1|SHA224|SHA256|SHA384|SHA512)[ \t(]/) return
  ctx = (low ~ KW_CONTEXT)

  # `/` and `=` are excluded from the token body on purpose. With them in, an
  # entire filesystem path or a whole KEY=value string parses as one "token",
  # which was the single largest source of entropy noise when measured. `=` is
  # still accepted as trailing base64 padding. Standard-base64 secrets split at
  # `/` into chunks, and a chunk of 24+ random characters still trips the rule.
  rest = line; seen = 0
  while (match(rest, /[A-Za-z0-9+_-]{20,}={0,2}/) && seen < MAXTOKENS) {
    t = substr(rest, RSTART, RLENGTH)
    prevch = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : ""
    nextch = substr(rest, RSTART + RLENGTH, 1)
    # the word-run before the token, used to tell a URL component from a value
    preword = substr(rest, 1, RSTART - 1)
    sub(/^.*[ \t]/, "", preword)
    rest = substr(rest, RSTART + RLENGTH)
    seen++

    # Trailing base64 padding is not part of the value, and leaving it attached
    # stopped `VYUHA_ADMIN_PASSWORD=` from being recognised as an identifier.
    sub(/=+$/, "", t)
    if (length(t) < 20) continue
    if (t ~ UUID || t ~ SEQUENTIAL || t ~ IDENTIFIER) continue
    # butted against / or . means it is part of a path, URL or dotted name
    if (prevch == "/" || prevch == "." || nextch == "/" || nextch == ".") continue
    if (prevch == "$") continue                        # shell variable reference
    # Inside a URL. Only skipped for the context-free layer: a URL on a line
    # that also mentions a secret still deserves a look.
    if (!ctx && index(preword, "://") > 0) continue

    e = entropy(t)
    if (ctx) {
      if (length(t) >= ENT_CONTEXT_LEN && e >= ENT_CONTEXT_MIN) {
        emit(f, n, "high-entropy-context", mask_token(line, t)); return
      }
      continue
    }
    if (t ~ HEXONLY) continue        # hex without context: SHAs, checksums
    if (length(t) < ENT_VALUE_LEN || e < ENT_VALUE_MIN) continue
    if (!in_value_position(line, t)) continue
    emit(f, n, "high-entropy-value", mask_token(line, t))
    return
  }
}

# True when the token is quoted, or is the entire right-hand side of = or :.
function in_value_position(line, t,   qt) {
  qt = quotemeta(t)
  if (line ~ ("[\"']" qt "[\"']")) return 1
  if (line ~ ("[=:][ \t]*" qt "[ \t]*[,;]?[ \t]*$")) return 1
  return 0
}

function quotemeta(s,   out, i, c) {
  out = ""
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (index("\\^$.[]|()*+?{}/", c)) out = out "\\" c
    else out = out c
  }
  return out
}

function entropy(s,   i, c, n, f, e) {
  n = length(s)
  delete cnt
  for (i = 1; i <= n; i++) { c = substr(s, i, 1); cnt[c]++ }
  e = 0
  for (c in cnt) { f = cnt[c] / n; e -= f * log(f) / log(2) }
  return e
}

function check_filename(f,   lf) {
  lf = tolower(f)
  if (lf ~ TEMPLATE_NAME) return
  if (lf ~ SENSITIVE_NAME) pending[f] = 1
}

function mask_key(line,   m, pre, post) {
  if (!match(line, KEYS)) return line
  m = substr(line, RSTART, RLENGTH)
  if (m ~ /^-----BEGIN/ || m ~ /^PuTTY/) return line   # the header is not the secret
  pre = substr(line, 1, RSTART - 1); post = substr(line, RSTART + RLENGTH)
  return pre substr(m, 1, 4) "…" post
}

function mask_url(line,   pre, m, post, user) {
  if (!match(line, URLCRED)) return line
  m = substr(line, RSTART, RLENGTH)
  pre = substr(line, 1, RSTART - 1); post = substr(line, RSTART + RLENGTH)
  user = m; sub(/:[^:@]*@$/, "", user)
  return pre user ":…@" post
}

function mask_token(line, t,   i) {
  i = index(line, t)
  if (!i) return line
  return substr(line, 1, i - 1) substr(t, 1, 4) "…" substr(line, i + length(t))
}

function mask_tail(line, val,   i) {
  i = index(line, val)
  if (!i || length(val) < 5) return line
  return substr(line, 1, i - 1) substr(val, 1, 4) "…" substr(line, i + length(val))
}

function emit(f, n, rule, text) {
  sub(/^[ \t]+/, "", text)
  if (length(text) > MAXLEN) text = substr(text, 1, MAXLEN) "…"
  print f US n US rule US text
}

END {
  # File-level findings are held until the whole diff is read, so a marker
  # anywhere in the file's added lines can waive them.
  for (f in pending)
    if (!(f in allowed))
      print f US 0 US "sensitive-filename" US "staged path matches a credential-file pattern"
}
