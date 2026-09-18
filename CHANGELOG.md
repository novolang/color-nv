# Changelog

## 0.1.0 — 2026-09-18

First implementation of the interface published as 0.0.1. Every `pub fn`
has a body, no `todo()` remains in `src/`, and no signature changed.

### Added

- **Every conversion, against the document that defines it.** The sRGB
  transfer function is IEC 61966-2-1's, with the linear segment below
  0.04045 and the 2.4 power above it. The sRGB/XYZ matrices are Bruce
  Lindbloom's published values. CIE L\*a\*b\* uses the exact rationals
  216/24389 and 24389/27 rather than the rounded 0.008856 and 903.3, so
  the two branches of the curve meet to the last bit. Chromatic
  adaptation is Bradford, which is what ICC profiles use. Oklab is Björn
  Ottosson's matrices at the ten decimals he publishes, and reproduces
  his reference values for white and the three primaries to every digit
  he gives.
- **The CSS text forms.** All four `#` lengths, `rgb()`, `rgba()`,
  `hsl()` and `hsla()` with the comma grammar and the space grammar, the
  slash alpha, percentage channels, `deg` on a hue, and all 148 named
  colours in both directions. A name that is not in the table is refused
  with the nearest keyword attached to the message.
- **`tests/coverage.sh`** reports the union of the five per-suite
  `novo test --cov` runs, which is 100% of the instrumented lines under
  `src/` with no `cov: skip` marker anywhere.
- **`tests/alloc_probe.nv` and `tests/alloc_scan.sh`** assert the
  foundation contract by reading the compiled output: 41 conversion
  functions, zero calls to the allocator. The conversion path between
  the unboxed working types runs entirely in registers.

### Changed

- **The floor is now `novo >= 0.9.1`**, raised from 0.8.9. 0.9.1 is the
  toolchain that built and tested these bytes and no older one has been
  tried. The sources use no 0.9.x-only construct, so an older toolchain
  may well take them; nobody has run it.
- **Two documented behaviours were wrong and are corrected in the
  documentation, not in the signatures.** `colormix.to_grey` said that
  averaging the three channels makes reds too light and blues too dark.
  It is the other way round: the flat average answers 85 for every
  primary, where the luminance-preserving grey of red is 127 and of blue
  is 76. And the example on `contrast.nearest_passing` showed a search
  towards a lighter colour under the flag that asks for a darker one.
- **`contrast.ratio_over` composites in linear light, and the README now
  says what that costs.** It is the physically correct composite and it
  is not what a browser paints: half coverage of black on white measures
  1.92 here and 3.95 as a browser renders it. The behaviour is as it was
  published; the disclosure is new.
- **`srgb.alpha_from_byte` clamps its argument into `0 ..= 255`** before
  dividing. The interface did not say what an out-of-range byte did.
- **The byte rounding no longer calls `math.round`.** The clamp has
  already put the value in range, so `+ 0.5` and a truncating cast is
  the same answer and does not drag in a maths library routine.
- **The registry now records one tier rather than five.** The 0.0.1
  release was measured as checking clean at every tier, which was true
  of a package whose every body was a `todo()` — that one call is
  admitted everywhere, so there was nothing to refuse. Real bodies are
  measured against the real rules, and these check clean at the
  application tier. No function in the package declares a tier, which
  is how the interface published them.

### Removed

- **The device claim, and `tests/embedded_probe.nv` with it.** 0.0.1 said
  the arithmetic surface builds for a microcontroller. It does not, for
  two separate reasons the README now sets out: the transfer function
  needs a power function the embedded target refuses, and `Srgb8` and
  `Srgba8` are heap values a target with no allocator cannot construct.

### Known limitations

- **`Srgb8` and `Srgba8` are still boxed.** 0.0.1 explained that
  SPEC section 14.5 kept an unboxed struct out of a `Result` payload, an
  optional payload, a tuple element, an enum payload and a field of a
  boxed struct, and that a storage colour occupies all five. novo-lang
  0.9.1 lifted that restriction, and taking it here would make a list of
  colours a flat buffer and would fix half of the device claim. It is
  not taken in this release: doing so exposed two reference-counting
  defects in the compiler, both filed, and a package that shipped around
  a defect would keep the scar after the defect was fixed. The change is
  held for the release that follows them.

## 0.0.2 — 2026-09-15

- README rewritten to the package README style guide (docs/writing-a-readme.md); no change to the interface.

## 0.0.2 — 2026-09-15

- README rewritten to the package README style guide (docs/writing-a-readme.md); no change to the interface.

## 0.0.1

- The interface: sRGB in bytes and in floats, linear RGB, HSL, HSV,
  CIE XYZ, CIE Lab and Oklab with the conversions between them; alpha
  as a value beside a colour rather than a channel inside one; the CSS
  hex and functional forms read and written; mixing, ramps and
  compositing in a named space; and the WCAG contrast ratio with its
  thresholds as functions.
- Every body is `todo()`. Nothing is implemented.
