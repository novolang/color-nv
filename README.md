# color-nv

**Status: NOT IMPLEMENTED — interface only.**

Every public function below is published with its signature and its
effect row, and every body is `todo()`. Installing this package works;
calling it panics with `not implemented`.

## What this is

Colour as a value. A colour is a point in a named space — sRGB in the
bytes a file holds and in the floats a blend needs, linear-light RGB,
HSL, HSV, CIE XYZ, CIE L\*a\*b\* and Oklab — with the conversions
between them and the gamma story written down where a reader meets it
rather than buried. Alpha sits beside a colour rather than inside it,
because coverage means the same thing in every space and converting it
is a category error. On top of that: the CSS hex and functional forms
read and written, mixing and colour ramps in whichever space the caller
names, and the WCAG contrast ratio with its thresholds as functions
rather than four numbers a caller has to remember which of.

It is the bottom of novo-lang's imaging stack: png-nv, qoi-nv and
image-nv all depend on it and it depends on nothing. It is equally the
package a theme system, a terminal, a chart or an accessibility linter
wants on its own.

```
novo pkg add color-nv
novo pkg build
novo test
```

## The one example that will work

```novo
use colortext
use contrast
use srgb

fn readable_ink(background: Str) -> Result<Srgb8, ColorError>
    let bg = colortext.parse(background)!
    Ok(contrast.best_ink(bg.rgb))
```

Read a colour out of a config file, and answer with the black or white
that reads better on it — by comparing both WCAG ratios, not by
thresholding the luminance at half, which is the shortcut that puts
white text on yellow.

## The layer, and why

`core` — no effects at all, and unusually for this grid the claim needs
no argument. A colour conversion is arithmetic over numbers the caller
already holds: nothing is opened, nothing is waited for, no clock is
consulted, and there is not even a stream to reconcile with the budget
the way png-nv and qoi-nv have to. The whole package is floats, bytes
and three constant matrices.

**The device claim is real and is built.** `tests/embedded_probe.nv` is
firmware that dims an RGB LED — decode the transfer function, scale the
light, re-encode, pack the framebuffer word — and the audit's
`core-embedded` row compiles it for `--target=nrf52-qemu`. That is the
genuine embedded use of a colour package, and it is worth having
because halving a byte from 255 to 128 is about a fifth of the light,
so a device that dims by halving a byte has an LED that reads as almost
off.

The probe deliberately does not reach `colortext` (strings), the ramp
functions (lists) or anything returning a `Result`, because `Result`
does not build at `@tier(embedded)` at all today. The claim is about
the arithmetic surface and the probe's `use` lines are the whole
statement of which surface that is.

## The load-bearing interface

```novo
pub struct Srgb8                                    // encoded bytes: what a file holds
pub struct Srgba8                                   // a colour and a coverage, side by side

pub @value
struct Srgb                                         // encoded floats: what a blend needs
pub @value
struct LinearRgb                                    // light: what arithmetic on light needs

pub fn to_linear(c: Srgb) -> LinearRgb
pub fn to_srgb(c: LinearRgb) -> Srgb
```

Four types and two functions, and everything else in the package is
built on the distinction they draw. `Srgb` is gamma-encoded and
`LinearRgb` is not; there is no implicit conversion between them, and
`CieXyz` — and therefore Lab, Oklab and relative luminance — can only
be reached through `LinearRgb`. A caller who averages two `Srgb`
values gets the muddy midpoint that every naive blend produces, and a
caller who tries to hand encoded channels to `to_xyz` gets a type error
instead of a picture that is subtly wrong.

`Srgba8` is the same argument applied to alpha: the colour is one whole
field, so `p.rgb` is a thing you may convert and `p.a` is a number that
is never converted at all.

## Two places the design shows through

**`@value` is on the working types and not on the storage types, and
that was decided by the compiler rather than by taste.** A colour is
exactly the small fixed thing `@value` exists for — but SPEC § 14.5
admits an unboxed struct in a short list of positions, and a `Result`
payload, an optional payload, a tuple element, an enum payload and a
field of a boxed struct are all outside it. `Srgb8` and `Srgba8` have
to occupy every one of those: `colortext.parse` returns one through a
`Result`, `colortext.named` through an optional, png-nv's background
chunk is an optional colour, image-nv puts one in an enum payload. So
they are ordinary boxed structs, and `Srgb`, `Alpha` and the five space
types — which only ever appear as parameters and returns of conversions
that cannot fail — are `@value`. The version of this package that could
hold a palette in 768 contiguous bytes is the version that could not
parse `#c0ffee`.

**`ColorSpace` names where arithmetic happens; it is not a conversion
target.** Each space has its own type, so there is no
`convert(c, space)` that could return them all without a sum type
nobody wants. The enum earns its place on `mix`, `sample`, `lighten`
and their siblings, where both ends are sRGB and only the middle is in
another space — which is the case that actually comes up.

## The reference implementations, and what is specification

`palette` (Rust) and `colour` / `colour-science` (Python) are the
reference implementations; the CSS Color 4 test suite and the WCAG
worked examples are the oracle.

**Specification, and binding on this package**

- The sRGB transfer function (IEC 61966-2-1): the linear segment below
  0.04045 and the affine 2.4 power above it. The linear segment is not
  a rounding of the power and a decoder that used a flat 2.2 gamma is
  visibly wrong in the darkest levels.
- The sRGB primaries and the linear-RGB ↔ XYZ matrices built from them.
- CIE 1931 XYZ, CIE L\*a\*b\* and the D50 and D65 illuminants.
- The Bradford chromatic adaptation transform, which is what ICC
  profiles use.
- CSS Color Module Level 4: the four hex lengths, the `rgb()`/`hsl()`
  grammars in both the comma and the space form, and the named-colour
  table with `green` at `#008000` and both spellings of `gray`.
- WCAG 2.2: the relative luminance weights, the
  `(L1 + 0.05) / (L2 + 0.05)` ratio, and the thresholds 4.5 / 3.0 for
  AA, 7.0 / 4.5 for AAA and a flat 3.0 for non-text.

**Choices this package makes, which a test may not treat as
correctness**

- That HSL and HSV are defined over ENCODED sRGB. That is CSS's
  definition and every design tool's, and it is not a physical one.
- Oklab, which is a 2020 fit rather than a CIE standard. It is here
  because leaving it out means every caller reimplements it, and its
  matrices are the only numbers in this package with no ISO number
  behind them.
- ΔE\*76 as `contrast.difference` rather than ΔE\*2000. The older
  formula is less accurate and is the one whose answer a reader can
  predict, which matters more in a package where the number is a
  diagnostic.
- The strictness of the parser. A bare `c0ffee` with no `#`, a name in
  title case and an out-of-range channel are all refused where CSS
  would clamp or some parsers would accept, because a config file with
  `rgb(300, 0, 0)` in it is a mistake a person wants told about.

**Deliberately not ported:** APCA, the contrast model being drafted for
WCAG 3. Its exponents changed twice in 2022, and publishing a snapshot
of a moving target as though it were a standard would be worse than
not having it. CMYK and the ICC profile machinery are out of scope for
a `core` package with no file access; `color(display-p3 …)`, `lch()`
and `hwb()` parse far enough to be refused by name with
`ColorUnsupportedSpace`, which is a different message from a syntax
error on purpose.

## Status

Every function is `todo()`. `novo test` runs the API suite, and every
assertion in it reaches `not implemented: color-nv.<module>.<fn>` —
which is the expected result until the bodies land, and is what makes
the suite a description of the interface rather than of nothing.
`novo test --isolate tests/<file>` is the readable form: one verdict
per test, naming the function it stopped at.

| module | public types | functions | implemented |
| --- | --- | --- | --- |
| `srgb` | 4 | 17 | no |
| `colorspace` | 7 | 20 | no |
| `colortext` | 1 | 10 | no |
| `colormix` | 1 | 13 | no |
| `contrast` | 0 | 10 | no |
| **total** | **13** | **70** | **no** |
