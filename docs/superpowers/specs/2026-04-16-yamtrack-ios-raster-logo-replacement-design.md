# Yamtrack iOS Raster Logo Replacement Design

## Summary

Replace the current Yamtrack capsule-based branding assets with the new square raster mark in `docs/branding/new_logo_cropped.png`.

This pass intentionally treats the PNG as the canonical source asset rather than rebuilding vector sources. The same square master should drive both the shipped iOS app icon outputs and the active branding assets in `docs/branding`.

## Goals

- Ship the new vinyl-based logo as the app icon for the iOS app
- Make the repository's active branding assets match the shipped app icon
- Keep the rollout simple by using the approved square PNG directly
- Preserve the existing app icon asset catalog structure and filenames
- Avoid introducing extra crop logic now that the approved asset is already square

## Non-Goals

- Rebuilding the branding system in SVG
- Designing a new horizontal lockup from scratch
- Changing app UI layouts or adding new in-app branded image usage
- Refactoring unrelated design docs or earlier logo exploration files

## Approved Source Asset

The source of truth for this pass is:

- `docs/branding/new_logo_cropped.png`

The file is now a square raster asset and can be resized directly for app icon outputs without additional cropping.

## Product Decision

The project should follow the raster-first option that was approved during brainstorming:

- use `new_logo_cropped.png` as the canonical shipped mark for this pass
- regenerate all existing iOS app icon PNGs from that square master
- replace active branding assets under `docs/branding` so the repo reflects the new shipped logo direction

This is the fastest practical path and matches the user's preference to avoid extra crop work or a parallel SVG rebuild.

## Asset Replacement Scope

### iOS App Icon Outputs

Update the existing files in:

- `YamtrackiOS/Assets.xcassets/AppIcon.appiconset`

The replacement should keep the current asset catalog layout and slot mapping intact. Only the image contents should change.

Required outputs:

- `icon-20@2x.png`
- `icon-20@3x.png`
- `icon-29@2x.png`
- `icon-29@3x.png`
- `icon-40@2x.png`
- `icon-40@3x.png`
- `icon-60@2x.png`
- `icon-60@3x.png`
- `icon-marketing.png`

### Branding Assets

The active branding assets in `docs/branding` should be updated to reflect the new raster mark rather than the previous capsule-based SVG system.

This pass should prefer simple PNG-based outputs over vector reconstruction. If older SVG files remain in the repository for historical context, they should no longer represent the current branding direction.

At minimum, the docs branding area should make the new square PNG the clear current source asset.

## Implementation Approach

### Resizing Strategy

Use the square master directly and resize it to each required app icon dimension.

No additional crop or compositional adjustment should be introduced during export. The approved square composition is already the intended framing.

### File Compatibility

Preserve:

- the existing `AppIcon.appiconset/Contents.json`
- existing filenames expected by the asset catalog

This keeps Xcode integration unchanged while updating the visual output.

### Branding Consistency

The branding folder should align with what the app ships:

- `new_logo_cropped.png` becomes the current primary mark
- any regenerated PNG previews should derive from the same square source
- the old capsule mark should stop being presented as the active brand

## Validation

Required validation for this pass:

- confirm `new_logo_cropped.png` remains the approved square source asset
- confirm every generated app icon file matches the current required dimensions
- inspect the 40px and 58px outputs for small-size readability
- inspect the 87px, 120px, 180px, and marketing outputs for visual consistency
- verify the app icon asset catalog still references the same filenames and structure
- verify the docs branding folder clearly reflects the new raster mark as current

## Risks And Mitigations

### Risk: Raster Source Limits Future Flexibility

Using a PNG as the canonical source is fast, but it is less flexible than a vector master for future edits.

Mitigation:

- keep the approved square PNG at its full available resolution
- treat a future SVG rebuild as a separate follow-up if the brand system needs more durable source files

### Risk: Docs Branding Could Be Ambiguous

If old SVG files remain beside the new PNG without clarification, the repository could imply two active branding systems.

Mitigation:

- update the branding folder so the new raster asset is clearly the active current mark
- avoid leaving the old capsule assets positioned as the latest branding deliverables

## Open Questions Resolved

- The rollout should cover both the iOS app icon and the branding assets
- The project should use the square PNG directly rather than rebuilding SVG sources now
- No additional crop work is needed once `new_logo_cropped.png` is square
- Small app-icon sizes remain readable enough to proceed with this source asset
