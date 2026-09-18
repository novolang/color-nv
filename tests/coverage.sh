#!/usr/bin/env bash
# tests/coverage.sh — the package's measured line coverage over src/.
#
# `novo test --cov` measures one suite at a time and prints a number for
# that run.  `docs/publishing.md` § Test coverage asks for a
# package-wide number, and until a package-wide mode lands the rule is
# checked by hand.  No single suite here reaches the whole package, so
# the number that matters is the union over all five, and this script
# computes that union.
#
# It reads the two files `novo test --cov` leaves in `_novo/`:
#
#   color-nv.cov.lines   every instrumented statement, as `<file> <line>`
#   color-nv.cov         the ones that ran, as `<file> <line> <hits>`
#
# and reports, per source file, which instrumented lines no suite
# reached.  A line excused with a `// cov: skip — <reason>` marker
# directly above it is listed separately with its reason, so an excuse
# is visible on every run rather than only in a review.
#
#   bash tests/coverage.sh          # the union, and every uncovered line
#
# The exit status is 0 when every line under src/ is covered or excused
# and 1 otherwise.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
NOVO="${NOVO:-$HOME/.novo/bin/novo}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

suites=(tests/*_tests.nv)
echo "coverage: ${#suites[@]} suite(s)"
for suite in "${suites[@]}"; do
  if ! "$NOVO" test "$suite" --cov >"$WORK/$(basename "$suite").log" 2>&1; then
    echo "coverage: $suite FAILED — see $WORK, coverage is meaningless until it is green" >&2
    grep -E '✗|assertion|error' "$WORK/$(basename "$suite").log" | head -5 >&2
    exit 1
  fi
  cat _novo/color-nv.cov >>"$WORK/hits"
  cp _novo/color-nv.cov.files "$WORK/files"
  cat _novo/color-nv.cov.lines >>"$WORK/lines"
  printf '  %-34s %s\n' "$(basename "$suite")" \
    "$(grep -E '^  Lines:' "$WORK/$(basename "$suite").log" | head -1 | sed 's/^ *//')"
done

python3 - "$WORK" <<'PY'
import os, re, sys

work = sys.argv[1]
names = {}
for line in open(os.path.join(work, "files")):
    fid, path = line.split(None, 1)
    names[fid] = path.strip()

def is_src(fid):
    return "/src/" in names.get(fid, "")

instrumented = set()
for line in open(os.path.join(work, "lines")):
    fid, ln = line.split()
    if is_src(fid):
        instrumented.add((fid, int(ln)))

hit = set()
for line in open(os.path.join(work, "hits")):
    fid, ln, _ = line.split()
    if is_src(fid):
        hit.add((fid, int(ln)))

skip = re.compile(r"//\s*cov:\s*skip\s*—\s*(.+)")
sources = {fid: open(p).read().split("\n") for fid, p in names.items() if is_src(fid)}

def excuse(fid, ln):
    """The reason on the nearest `// cov: skip` marker above this line."""
    lines = sources[fid]
    i = ln - 2
    while i >= 0 and (lines[i].strip().startswith("//") or not lines[i].strip()):
        m = skip.search(lines[i])
        if m:
            return m.group(1).strip()
        i -= 1
    return None

missing, excused = [], []
for key in sorted(instrumented - hit):
    reason = excuse(*key)
    (excused if reason else missing).append((key, reason))

total = len(instrumented)
covered = len(instrumented & hit)
pct = 100.0 * covered / total if total else 100.0
print("")
print("  src/ lines instrumented : %d" % total)
print("  reached by some suite   : %d  (%.1f%%)" % (covered, pct))
print("  excused with a marker   : %d" % len(excused))
print("  uncovered and unexcused : %d" % len(missing))

for (fid, ln), reason in excused:
    print("    skip %s:%d — %s" % (os.path.basename(names[fid]), ln, reason))
for (fid, ln), _ in missing:
    text = sources[fid][ln - 1].strip()
    print("    MISS %s:%d  %s" % (os.path.basename(names[fid]), ln, text[:80]))

sys.exit(1 if missing else 0)
PY
