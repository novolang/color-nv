#!/usr/bin/env bash
# tests/alloc_scan.sh — the conversion path allocates nothing, checked
# by reading the compiled output rather than by asserting it in prose.
#
# `novo build` writes the module's LLVM to `_novo/<name>.ll` before it
# invokes clang, so the IR is there to read.  `--opt=0` keeps the
# functions separate.  At the default optimisation level the whole probe
# inlines into `novo_main`, there is nothing left to attribute an
# allocation to, and the check would pass over an empty file.
#
# The functions scanned are every function of `colorspace`, which is the
# transfer function, the matrices, the cylindrical conversions and the
# white points, all of which work in the `@value` types.  The half of
# `srgb` that reads and compares rather than constructs is scanned with
# them.
#
# The constructors are excluded by name rather than by the scan quietly
# not looking at them.  `rgb8`, `to_srgb8`, `with_alpha`, `opaque`,
# `unpack_rgb`, `unpack_argb`, `black`, `white` and `transparent` build
# an `Srgb8` or an `Srgba8`, which are boxed structs, so each one
# allocates its cell.  The header of src/srgb.nv is where that split is
# explained.
#
#   bash tests/alloc_scan.sh
#
# The exit status is 0 when no scanned function allocates and 1
# otherwise.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
NOVO="${NOVO:-$HOME/.novo/bin/novo}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if ! "$NOVO" build --opt=0 -o "$WORK/probe.bin" tests/alloc_probe.nv >"$WORK/build.log" 2>&1; then
  echo "alloc_scan: the probe does not build" >&2
  grep -E 'error' "$WORK/build.log" | head -5 >&2
  exit 1
fi

ll="_novo/alloc_probe.ll"
[ -f "$ll" ] || { echo "alloc_scan: no $ll emitted" >&2; exit 1; }

python3 - "$ll" <<'PY'
import re, sys

src = open(sys.argv[1]).read()
fns = re.compile(r'^define[^\n]*?@([A-Za-z0-9_.]+)\([^\n]*\{\n(.*?)\n\}', re.S | re.M)

# The conversion path is all of `colorspace` and the reading half of
# `srgb`.
path = re.compile(r'^novo_user_(colorspace_|srgb_)')
# The constructors of the two boxed storage types, named rather than
# hidden.
boxed = re.compile(r'^novo_user_srgb_(rgb8|to_srgb8|with_alpha|opaque|'
                   r'unpack_rgb|unpack_argb|black|white|transparent)$')

seen, offenders = 0, []
for m in fns.finditer(src):
    name, body = m.group(1), m.group(2)
    if not path.match(name) or boxed.match(name):
        continue
    seen += 1
    n = len(re.findall(r'call[^\n]*@novo_alloc', body))
    if n:
        offenders.append('%s: %d novo_alloc call(s)' % (name, n))

if seen < 35:
    print('FAIL only %d conversion functions found in the IR — the probe '
          'or the name scheme moved, and this check was measuring nothing'
          % seen)
elif offenders:
    print('FAIL ' + '; '.join(offenders))
else:
    print('OK %d conversion functions, zero novo_alloc' % seen)
PY
