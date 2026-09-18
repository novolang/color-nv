# Changelog

## 0.1.1 — 2026-09-18

The documentation and comments in plain prose; no signature changed.

## 0.1.0 — 2026-09-18

sRGB in bytes and in floats, the seven colour spaces and the conversions
between them, the CSS text forms, mixing and compositing, and the WCAG
contrast ratio with its thresholds.

- Every conversion is against the document that defines it. The sRGB
  transfer function is IEC 61966-2-1's, with the linear segment below
  0.04045 and the 2.4 power above it. The sRGB and XYZ matrices are
  Bruce Lindbloom's published values. CIE L\*a\*b\* uses the exact
  rationals 216/24389 and 24389/27 rather than the rounded 0.008856 and
  903.3, so the two branches of the curve meet to the last bit.
  Chromatic adaptation is Bradford, which is what ICC profiles use.
  Oklab is Björn Ottosson's matrices at the ten decimals he publishes,
  and reproduces his reference values for white and the three primaries
  to every digit he gives.
- The CSS text forms are read and written. All four `#` lengths,
  `rgb()`, `rgba()`, `hsl()` and `hsla()` with the comma grammar and the
  space grammar, the slash alpha, percentage channels, `deg` on a hue,
  and all 148 named colours in both directions. A name that is not in
  the table is refused with the nearest keyword attached to the message.
- `tests/coverage.sh` reports the union of the five per-suite
  `novo test --cov` runs, which is 100% of the instrumented lines under
  `src/` with no `cov: skip` marker anywhere.
- `tests/alloc_probe.nv` and `tests/alloc_scan.sh` read the compiled
  output for the conversion path: 41 conversion functions, and no call
  to the allocator. The path between the unboxed working types runs
  entirely in registers.
- The floor is `novo >= 0.9.1`, raised from 0.8.9. 0.9.1 is the
  toolchain that built and tested these bytes and no older one has been
  tried. The sources use no 0.9.x-only construct, so an older toolchain
  may well take them. Nobody has run one.
- Two documented behaviours were wrong and are corrected in the
  documentation rather than in the signatures. `colormix.to_grey` said
  that averaging the three channels makes reds too light and blues too
  dark. It is the other way round. The flat average answers 85 for every
  primary, where the luminance-preserving grey of red is 127 and of blue
  is 76. The example on `contrast.nearest_passing` showed a search
  towards a lighter colour under the flag that asks for a darker one.
- `contrast.ratio_over` composites in linear light, and the README now
  says what that costs. It is the physically correct composite and it is
  not what a browser paints. Half coverage of black on white measures
  1.92 here and 3.95 as a browser renders it. The behaviour is as it was
  published and the disclosure is new.
- `srgb.alpha_from_byte` clamps its argument into `0 ..= 255` before
  dividing.
- The byte rounding no longer calls `math.round`. The clamp has already
  put the value in range, so `+ 0.5` and a truncating cast is the same
  answer and does not drag in a maths library routine.
- The registry records the application tier. No function in the package
  carries a `@tier` annotation, and the package checks clean at the
  application tier.
- `tests/embedded_probe.nv` is removed. No part of the package builds
  for a microcontroller, for two separate reasons the README sets out.
  The transfer function needs a power function the embedded target
  refuses, and `Srgb8` and `Srgba8` are heap values a target with no
  allocator cannot construct.
- `Srgb8` and `Srgba8` are boxed. SPEC section 14.5 kept an unboxed
  struct out of a `Result` payload, an optional payload, a tuple
  element, an enum payload and a field of a boxed struct, and a storage
  colour occupies all five. novo-lang 0.9.1 lifted that restriction, and
  taking it here would make a list of colours a flat buffer and would
  let half the package build for a device. It is not taken in this
  release. Doing so exposed two reference-counting defects in the
  compiler, both filed, and the change is held for the release that
  follows them.

## 0.0.2 — 2026-09-15

- README rewritten to the package README style guide (docs/writing-a-readme.md); no change to the interface.

## 0.0.1

- The declarations: sRGB in bytes and in floats, linear RGB, HSL, HSV,
  CIE XYZ, CIE Lab and Oklab with the conversions between them; alpha
  as a value beside a colour rather than a channel inside one; the CSS
  hex and functional forms read and written; mixing, ramps and
  compositing in a named space; and the WCAG contrast ratio with its
  thresholds as functions. No function has a body.
