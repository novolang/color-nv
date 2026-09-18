# color-nv

A colour is a point in a named space, and sRGB is the space almost every
image file, stylesheet and framebuffer means when it says nothing. sRGB is
defined by [IEC 61966-2-1](https://webstore.iec.ch/publication/6169). This
package holds a colour as a value in sRGB and in six other spaces, converts
between them, reads and writes the forms
[CSS Color Module Level 4](https://www.w3.org/TR/css-color-4/) defines, and
measures the contrast ratio
[WCAG 2.2](https://www.w3.org/TR/WCAG22/) defines. Four other packages on the
registry are built on it: [png-nv](https://novo-lang.org/packages/png-nv),
[qoi-nv](https://novo-lang.org/packages/qoi-nv),
[svg-nv](https://novo-lang.org/packages/svg-nv) and
[raster-nv](https://novo-lang.org/packages/raster-nv).

## What it is

An sRGB channel is stored as a byte, and that byte is not an amount of light.
The value 128 is not half the photons of 255. It is about a fifth of them.
The mapping from a stored channel to light is the **sRGB transfer function**:
a short linear segment for small values and a 2.4 power above it. A channel
that has had the transfer function applied is **gamma-encoded**. A channel
that has had it undone is **linear-light**.

That distinction decides which arithmetic is correct. Averaging two colours,
resizing an image, blurring, and compositing one pixel over another are all
arithmetic on light, so they belong on linear-light values. The symptom of
getting it wrong is a red-to-green gradient that goes dark and muddy in the
middle. Conversion to CIE XYZ is also defined on linear light, and every
space reached through XYZ inherits that.

Some arithmetic is conventionally done on the encoded channels instead: a hue
rotation, or "make this ten percent lighter". CSS and every design tool
define HSL and HSV over encoded sRGB, and this package matches them.

Seven spaces are named here. **sRGB** is the encoded form. **Linear RGB** is
the same primaries with the transfer function undone. **HSL** and **HSV** are
cylindrical restatements of encoded sRGB, so their first channel is a hue
angle that wraps at 360. **CIE XYZ** is the 1931 tristimulus space every
other space is defined against. **CIE L\*a\*b\*** is a near-uniform space, so
that equal distances in it are roughly equal differences to a viewer.
**Oklab** is a 2020 fit of the same idea, published by Björn Ottosson and
adopted by CSS Color Module Level 4.

A **white point** is the illuminant a set of tristimulus values was measured
under. sRGB is a D65 space. CIE Lab is quoted against D50 in print and D65 on
screen, and the two disagree by a visible step, so every Lab conversion here
takes the white point rather than picking one.

**Alpha** is a coverage fraction, not a colour channel. It means the same
thing in every space, so converting it is a category error. This package
keeps it in a field beside a colour rather than inside one.

| Quantity | Value |
| --- | --- |
| Channels in an `Srgb8` | 3, each `0 ..= 255` |
| Channels in an `Srgb` | 3, each nominally `0.0 ..= 1.0` |
| Colours an `Srgb8` can hold | 16 777 216 |
| The sRGB transfer function's linear segment ends at | 0.04045 encoded |
| The exponent above that segment | 2.4 |
| Named CSS colour keywords | 148 |
| Hex forms accepted | 4 (three, four, six and eight digits) |
| Contrast ratio range | 1.0 to 21.0 |
| The flare term in the ratio | 0.05 |
| Relative luminance weights, red, green, blue | 0.2126, 0.7152, 0.0722 |

## Install

```
novo pkg add color-nv
```

## Example

```novo
use srgb
use contrast

fn main() [io]
    // The background colour, as the three gamma-encoded bytes a file holds.
    let background = srgb.rgb8(255, 214, 0)

    // Black or white, whichever reads better on that background.
    let ink = contrast.best_ink(background)

    // The WCAG contrast ratio between the two, between 1.0 and 21.0.
    println("${contrast.ratio(background, ink)}")
```

Build and test with `novo pkg build` and `novo test`.

## What the package contains

| Module | Contents |
| --- | --- |
| `srgb` | The colour types themselves: encoded bytes, encoded floats, an alpha, and a colour with an alpha beside it. The conversions between byte and float, the masking and clamping rules, packing into an integer word, and byte equality. |
| `colorspace` | The seven spaces, the white points, the sRGB transfer function in both directions, and every conversion between spaces. |
| `colortext` | A colour written down: the four hex forms, the CSS functional forms, the 148 named colours, the errors a caller gets when the text is none of them, and the formatters that write each form back. |
| `colormix` | Blending two colours, walking a ramp through several, premultiplying and compositing, and the lighten, saturate, hue-rotate and greyscale operations. |
| `contrast` | The WCAG relative luminance, the contrast ratio over it, the pass and fail tests for each conformance level, the nearest passing colour, and a CIE Lab colour difference. |

## How to choose an entry point

**`srgb` on its own is enough for a program that only stores and compares
colours.** A codec reading pixels, a palette lookup and a framebuffer write
need the types, the packers and `same8`, and nothing else.

**`colortext.parse` is the way in from configuration.** It accepts every form
this package knows and answers a colour with an alpha, or an error saying
which rule the text broke. `parse_hex` accepts only the `#` forms, for a
caller who does not want names or functional notation.

**`colorspace` is for a program doing arithmetic on light.** Convert to
`LinearRgb`, do the work, convert back. Nothing in the package does that
conversion behind a caller's back.

**`colormix` is for a program producing a colour from other colours.** Every
function in it takes the space the arithmetic happens in, so the caller
decides once and the module does the conversions.

**`contrast` is for a program checking a colour pair.** It answers a number
and then answers whether that number passes, which are separate questions.

## The rules a user needs

1. **Encoded and linear are different types, and there is no implicit
   conversion.** `Srgb` is gamma-encoded, `LinearRgb` is not, and `CieXyz` is
   reachable only from `LinearRgb`. A caller who hands encoded channels to
   `to_xyz` gets a type error rather than a picture that is subtly wrong. The
   transfer function is IEC 61966-2-1's, with the linear segment below 0.04045
   and the 2.4 power above it.
2. **Averaging two encoded colours is not averaging light.** The midpoint of
   red and green in encoded sRGB is a dark olive and in linear RGB it is a
   bright one. Both are answers to different questions, which is why every
   function in `colormix` takes a `ColorSpace` and none of them defaults it.
3. **HSL and HSV here are defined over encoded sRGB.** That is CSS Color
   Module Level 4's definition and every design tool's. It is not a physical
   one, so a lightness of 0.5 in HSL is not half the light.
4. **A hue interpolation takes the short way round the circle.** From 350
   degrees to 10 degrees it goes forwards 20, not backwards 340. That is CSS
   Color Module Level 4's `shorter hue` default. `colormix.mix_hue_long` is
   the escape for a caller who wants the long way. A ramp through several
   stops is therefore not the same as the two-at-a-time mixes it is made of,
   because each segment picks its own direction.
5. **`srgb.rgb8` masks and `srgb.clamp_byte` clamps.** `rgb8(300, 0, 0)` has a
   red of 44, following the `as u8` rule in SPEC section 13.3. A caller who
   wants 300 to become 255 calls `clamp_byte` first. Every resampling filter
   with negative lobes produces channels out of range, and clamping is what
   stops a sharpened edge from inverting.
6. **The byte and float forms divide by 255, not 256.** 255 becomes exactly
   1.0 and the round trip through `to_srgb8` is the identity for all
   16 777 216 colours. Dividing by 256 makes white 0.996 and breaks that.
7. **A channel outside `0.0 ..= 1.0` is out of gamut, not invalid.** A Lab
   colour converted back to sRGB routinely lands outside the cube. Nothing
   clamps behind a caller's back on the way through a space, because that
   would make the round trip lossy with nothing reporting it.
   `srgb.clamp_unit` is where a caller decides.
8. **Alpha in an `Srgba8` is not premultiplied.** `Srgba8 { rgb: white, a: 0 }`
   is a transparent white, not a black. PNG and QOI both store unassociated
   alpha, so that is the convention here. `colormix.premultiply` is the
   conversion for a caller compositing a whole buffer.
9. **`srgb.unpack_argb` reads the alpha as the high byte.** That is the order
   Android and most framebuffer words use. It is the opposite of the
   `#rrggbbaa` that CSS and `colortext.format_hex_alpha` write. Both orders
   exist and the names say which is which.
10. **Every Lab conversion takes a white point.** sRGB is D65. A caller coming
    from sRGB wants `WhiteD65` unless they know otherwise, and
    `colorspace.adapt` is the Bradford transform that moves tristimulus values
    between illuminants.
11. **`contrast.ratio` does not care which argument is the foreground.**
    `ratio(a, b)` and `ratio(b, a)` are the same number, because the formula
    puts the lighter colour on top itself. WCAG 2.2 defines it in its glossary
    entry for "contrast ratio", as `(L1 + 0.05) / (L2 + 0.05)`.
12. **The pass thresholds are functions, not constants.** Which of WCAG 2.2's
    numbers applies depends on the conformance level, the text size and the
    font weight together, and "large" means 18 point or 14 point bold rather
    than any pixel size. `contrast.meets_aa`, `meets_aaa` and `meets_non_text`
    take the ratio and whether the text is large, so the rule that selects the
    number stays in the package. Success criteria 1.4.3, 1.4.6 and 1.4.11 are
    the three rules.
13. **The parser refuses rather than guesses.** A bare `c0ffee` with no `#`, a
    colour name in title case, and a channel out of range are all errors here,
    where some parsers clamp or accept. A config file holding
    `rgb(300, 0, 0)` is a mistake the author wants told about.
14. **Formatting is not the parser's inverse.** `colortext.format_hex` always
    writes the six-digit lower-case form, even for a colour the three-digit
    form could carry. A round trip is text-lossy and colour-exact, so two
    files that differ only in hex shorthand compare equal after a format pass.
15. **`colortext.parse` answers a colour with an alpha, always.** A form with
    no alpha in it answers 255. A caller wanting only the colour reads the
    `rgb` field.

## Running on a microcontroller

**No part of this package builds for a microcontroller.** There are two
reasons and they are separate.

**The transfer function needs a power function.** Converting a channel between
stored sRGB and light raises a number to the power 2.4. On a microcontroller
target the compiler refuses that call. It expands to a maths library routine,
and linking that library into a 64 KB image costs more than the image has. A
device implementation has to use fixed-point arithmetic or supply its own
power function through the foreign function interface. Neither is in this
package.

**`Srgb8` and `Srgba8` are heap values.** A colour and a pixel are ordinary
structs here, and a microcontroller target has no heap allocator to build one
in. novo-lang 0.9.1 admitted unboxed storage for these two types, which would
fix this half. Taking it exposed two reference-counting defects in the
compiler, both filed, and this release waits for them.

The arithmetic between the float types — `Srgb`, `LinearRgb`, `Hsl`, `Hsv`,
`CieXyz` and `CieLab` — allocates nothing on any target.
`tests/alloc_scan.sh` checks that by reading the compiled output. It is a
different property from running on a device, and it holds.

## What is not included

- **APCA**, the contrast model drafted for WCAG 3. Its exponents changed twice
  in 2022. Publishing a snapshot of a moving target as though it were a
  standard would be worse than leaving it out.
- **ΔE\*2000.** `contrast.difference` is ΔE\*76, whose answer a reader can
  predict, which matters more where the number is a diagnostic.
- **CMYK and ICC profile handling.** Both need file access, which a package
  with no effects does not have.
- **`color(display-p3 …)`, `lch()` and `hwb()`.** The parser reads far enough
  to name them and refuses with `ColorUnsupportedSpace`, which is a different
  error from a syntax error on purpose.
- **A palette held as one flat buffer.** A list of colours is a list of heap
  values, not 768 contiguous bytes. `Srgb8` and `Srgba8` are stored that way
  because a colour crosses boundaries an unboxed value could not: `parse`
  returns one through a `Result`, `named` returns one through an optional, and
  packages built on this one put a colour in an enum and in a struct field.
  novo-lang 0.9.1 lifted that restriction and a later release will take it.
  The seven float types are already unboxed, so every conversion between them
  runs without allocating.
- **A contrast ratio measured the way a browser paints.**
  `contrast.ratio_over` composites a translucent foreground onto its
  background in linear light, which is what a camera would have recorded. A
  browser composites on the stored channels instead, so the two disagree: half
  coverage of black on white is 1.92 here and 3.95 as a browser paints it. A
  caller auditing a rendered page should composite with the browser's rule and
  pass the result to `contrast.ratio`.
- **A `convert(colour, space)` function.** Each space has its own type, so one
  function returning all of them would need a sum type. `ColorSpace` names
  where arithmetic happens instead, on `mix`, `sample`, `lighten` and their
  siblings, where both ends are sRGB and only the middle is elsewhere.

## Related packages

- [png-nv](https://novo-lang.org/packages/png-nv) is the PNG codec. It uses
  the colour types here for its palette, its background chunk and its pixels.
- [qoi-nv](https://novo-lang.org/packages/qoi-nv) is the QOI codec. Its index
  is defined in terms of byte equality, which is `srgb.same8`.
- [svg-nv](https://novo-lang.org/packages/svg-nv) is the SVG document model.
  It uses this package for every paint and stop colour.
- [raster-nv](https://novo-lang.org/packages/raster-nv) draws shapes into a
  surface. It composites with the rules in `colormix`.
- `std.term` in the standard library writes colour to a terminal. It speaks
  escape sequences rather than colour spaces, and `srgb.pack_rgb` is the value
  a 24-bit escape wants.

## Tests

```bash
novo test tests/srgb_tests.nv         # the colour values themselves
novo test tests/colorspace_tests.nv   # the spaces and the conversions
novo test tests/colortext_tests.nv    # reading and writing a colour as text
novo test tests/colormix_tests.nv     # blending, ramps and compositing
novo test tests/contrast_tests.nv     # luminance, the ratio and the thresholds
```

The reference implementations are `palette` in Rust and `colour-science` in
Python. The oracle for the text forms is the CSS Color Module Level 4 test
suite, and the oracle for the ratio is WCAG 2.2's own worked examples.

The suites assert the contract and the numbers. The contract: that 255 means
fully opaque exactly, that the byte and float forms round-trip, that masking
and clamping are different functions with different answers, that alpha never
passes through a colour conversion, that the space names are the CSS
spellings, that every refusal is the right variant of `ColorError` and not
merely an error, and that black on white is 21.0 and a colour against itself
is 1.0.

The numbers, each against the document that publishes it:

| Quantity | Source | Asserted to |
| --- | --- | --- |
| The transfer function at 0.04045, 0.5 and 1.0 | IEC 61966-2-1 | 1e-12 |
| The sRGB to XYZ matrix | Bruce Lindbloom's tables | 1e-10 |
| CIE L\*a\*b\* of the three primaries and of mid grey | Bruce Lindbloom's tables | 1e-4 |
| Bradford adaptation between D65 and D50 | Bruce Lindbloom's tables | 1e-7 |
| Oklab of white and of the three primaries | Björn Ottosson's reference values | 1e-4 |
| All 148 named colours, both directions | CSS Color Module Level 4 | exact |
| The contrast ratio of `#767676` and `#949494` on white | WCAG 2.2 | 1e-4 |

Two round trips are looser than the one-way values they are built from,
because the matrices published for each direction are rounded separately and
are therefore not exactly each other's inverses. Bradford lands within 1e-6 of
where it started and Oklab within 4e-7. Both tolerances are written at the
assertion that uses them.

Line coverage over `src/` is 100%, measured with `novo test --cov`. No single
suite reaches the whole package, so `tests/coverage.sh` runs all five and
reports the union.

`novo test --isolate tests/<file>` prints one verdict per test.

## Licence

Apache-2.0. See `LICENSE`.

<!-- docs/writing-a-readme.md is the style guide for this page. -->
