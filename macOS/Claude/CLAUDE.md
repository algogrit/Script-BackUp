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
