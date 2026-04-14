# Yamtrack iOS Logo Refresh Design

## Summary

Refresh the Yamtrack app icon and branding mark so the product reads more clearly as media tracking, while preserving the premium liquid-glass feel established in the current branding.

The new direction should center on an oversized vinyl record inside a rounded transparent glass tile. The vinyl should read as a real object at first glance, but stripped down to a minimal, Apple-like material treatment rather than an illustrated or comic style.

Progress should be communicated by exactly five colored groove lines on the vinyl. These grooves represent milestone progress states and must be the only visible track lines on the disc. Decorative or realistic filler grooves should be removed so the meaning stays legible at app-icon size.

## Goals

- Make the mark communicate "media tracking" faster than the current abstract capsule icon
- Keep the premium liquid-glass / modern iOS material feel
- Ensure the icon still reads clearly at small app-icon sizes
- Use the five colored groove lines as the primary progress metaphor
- Keep the composition distinctive enough to feel like Yamtrack rather than a generic record icon

## Non-Goals

- Designing a full multi-logo brand system beyond the app mark and immediate lockup updates
- Introducing text or letters into the icon itself
- Building a highly realistic photoreal render with dense texture detail
- Adding extra decorative vinyl grooves that compete with the five progress lines
- Redefining the app's broader color palette outside the icon needs for this pass

## Product Direction

The icon should become more descriptive without losing restraint.

The existing mark is elegant, but it does not immediately suggest what Yamtrack does. The refreshed mark should keep the same premium taste level while using a more legible metaphor: a vinyl record whose progress is shown through separated colored tracks.

The record should remain mostly black or smoky glass. Only the five progress grooves should carry color. This keeps the icon from becoming noisy while letting progress remain the focal idea.

The composition should follow the spirit of the provided glass-tile vinyl reference:

- rounded transparent tile
- oversized vinyl disc
- slight cropping or off-center placement for energy
- restrained metallic hub
- subtle reflections and refraction

## Core Composition

### Tile

The icon background should remain a rounded square glass tile rather than a bare disc.

The tile should:

- feel clear and layered, not frosted opaque
- use soft highlights and subtle edge refraction
- provide enough visual structure that the icon still feels premium on light and dark iOS surfaces
- avoid busy internal patterns or large background color fields

### Vinyl Placement

The vinyl should sit slightly oversized inside the tile so the composition feels intentional and dynamic rather than centered and static.

Recommended treatment:

- disc cropped subtly by the tile bounds
- disc slightly offset within the tile
- angle kept frontal or near-frontal so the groove system reads clearly

The icon should still read as a record first, not as a generic circular progress meter.

### Center Hub

The record hub should stay simple and precise:

- dark metallic center
- small spindle hole
- restrained radial sheen

The hub should help the object read as vinyl but must not become the visual focus.

## Progress Groove System

### Groove Count

The vinyl must show exactly five colored progress grooves.

These grooves correspond to fixed milestone states:

- 0%
- 10%
- 25%
- 50%
- 75%

### Groove Behavior

Each milestone groove must occupy its own concentric line.

Requirements:

- no groove overlaps
- no merged color bands
- no decorative filler grooves between milestone grooves
- clear separation between each colored line

The groove system should feel like five intentional record tracks rather than a rainbow ring chart.

### Groove Placement

The grooves should sweep around the record in an arc pattern that suggests progress accumulation.

The intended feel is:

- lines start near the upper region of the disc
- lines extend around the right side and lower arc
- the arrangement suggests an ordered progression rather than a full circular ring

Exact angles can be tuned during implementation, but the system should feel consistent and systematic, not randomly staggered.

### Groove Color

The five grooves should be the only saturated color in the icon.

They should use a warm-to-cool or milestone-friendly sequence that stays legible on the black disc. The palette can be refined during implementation, but it should stay bright, clean, and modern rather than neon or muddy.

## Material Direction

### Disc Material

The record should feel like smoky black liquid glass with subtle depth.

It should avoid:

- comic-style outlines
- flat vector-only shading
- noisy realistic groove texture
- matte plastic appearance

It should instead emphasize:

- glossy dark surface transitions
- soft reflected highlights
- subtle edge glow and rim light
- enough depth variation to suggest a premium physical object

### Simplicity Constraint

Although the material should feel premium, the final mark still needs to behave like a strong icon.

That means:

- broad lighting shapes over micro-detail
- minimal internal clutter
- strong silhouette at 29px and 60px icon sizes
- recognizability even when viewed quickly in the app grid

## Brand Assets In Scope

This pass should update the core branding assets that currently represent the mark:

- `docs/branding/yamtrack-mark.svg`
- `docs/branding/yamtrack-logo.svg`
- exported PNG branding previews as needed
- iOS app icon raster outputs in `YamtrackiOS/Assets.xcassets/AppIcon.appiconset`

The horizontal lockup should reuse the refreshed mark rather than inventing a separate symbol language.

## Deliverables

The implementation should produce:

- a refreshed square standalone mark suitable for app icon use
- a refreshed horizontal Yamtrack lockup using the new mark
- regenerated iOS app icon PNGs for all existing slots
- updated branding documentation text if the concept statement no longer matches the shipped mark

## Testing and Validation

This work is visual, but it still needs structured verification.

Required validation:

- confirm the SVG assets render correctly at full size
- confirm the exported iOS PNG sizes match the current `AppIcon.appiconset` requirements
- inspect the 29px, 40px, 60px, and marketing icon outputs for small-size legibility
- verify the five groove lines remain visually distinct after rasterization
- verify no extra groove lines remain in the shipped mark
- confirm the lockup stays visually aligned with the refreshed standalone mark

## Implementation Slices

### Slice 1: Mark Redesign

- replace the existing abstract capsule mark with the new glass-tile vinyl composition
- establish the five-groove system with separated milestone lines
- tune reflections, crop, and hub detail for clarity

### Slice 2: Lockup Update

- update the horizontal lockup to use the new mark
- preserve current wordmark treatment unless the new mark forces minor spacing adjustments

### Slice 3: Raster Export Refresh

- regenerate the PNG outputs used by the branding folder and app icon asset catalog
- ensure all filenames and asset catalog mappings remain compatible with the existing Xcode setup

### Slice 4: Validation and Cleanup

- inspect small icon sizes for readability
- update branding README copy if needed to match the new concept
- confirm the final asset set is internally consistent

## Open Questions Resolved

- The icon should remain inside a glass tile rather than becoming a bare vinyl disc
- The vinyl should read as a real record at first glance, not a purely abstract concentric symbol
- The record should stay mostly black / smoky glass, with color reserved for the five progress grooves
- The vinyl should be slightly oversized or cropped rather than perfectly centered
- The five milestone grooves should each live on their own separate line with no overlap
