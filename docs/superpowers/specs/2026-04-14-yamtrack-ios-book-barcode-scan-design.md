# Yamtrack iOS Book Barcode Scan Design

## Summary

Add a book-only barcode scanner to the existing `Add Media` flow in the iOS app.

V1 should stay intentionally narrow:

- scan visible book barcodes from the camera
- accept only valid ISBN-10 or ISBN-13 values
- look up matching books through Yamtrack's existing book providers
- always show a confirmation step before creating the tracked item
- fall back cleanly to the existing search or manual add flows when lookup fails

This feature should optimize for reliability over novelty. It should not depend on multimodal image recognition, generic object classification, or OCR in the first release.

## Goals

- Make adding books from a physical barcode materially faster than manual or typed search
- Reuse the existing `Add Media` flow instead of introducing a parallel camera-first add feature
- Keep matching logic deterministic by treating ISBN as the source of truth
- Require explicit user confirmation before creation, even when there is a single strong match
- Preserve current manual and provider search flows as the fallback path

## Non-Goals

- Scanning movies, games, comics, or other non-book media in v1
- OCR-based title extraction
- Automatic object recognition to determine media type
- Silent auto-add after scan
- A new top-level `Add From Camera` entry point in the library screen
- Provider-agnostic barcode resolution for non-book GTIN or UPC codes

## Product Direction

The first version should be framed as a reliability feature, not a broad "point your camera at anything" promise.

The app already has a working add flow with book providers and manual entry. Barcode scanning should be an accelerator inside that flow rather than a new primary destination. This keeps the product honest: the user is still clearly in "add a book" mode, and if scanning fails they are already one step away from typed search or manual entry.

The scan flow should feel like a shortcut for discovery only. Creation should continue using the same provider-backed create behavior the app already uses today.

## Entry Point

### Location

The scanner should live inside the existing `Add Media` screen.

Recommended shape:

1. user opens `Add Media`
2. user selects `Book`
3. the UI offers a `Scan Book Barcode` action alongside the existing source-driven add options

The scanner should not be promoted to its own top-level library shortcut in v1. That would imply a broader camera feature than the app actually supports.

### Relationship To Existing Add UI

`Book` remains the selected media type throughout the scan flow.

The scanner is an alternate discovery step for book creation, not a separate feature module with its own creation rules. If scanning fails or the user cancels, they should land back in the normal `Add Media` book context without losing the rest of the screen.

## Scanner Flow

### Camera Behavior

The iOS client should use Apple's live barcode scanning APIs and configure them only for relevant barcode symbologies used by books.

The scanner's job is narrow:

- detect barcodes in the live camera feed
- extract the scanned value
- validate and normalize ISBN input
- stop scanning once a valid ISBN is captured
- hand off to lookup and confirmation

The scanner should not attempt OCR, object classification, or title extraction in v1.

### ISBN Validation

The client should accept:

- ISBN-10
- ISBN-13

The client should normalize input before lookup:

- remove spaces and hyphens
- reject codes that fail checksum validation

The backend should own canonical ISBN normalization beyond that lightweight client cleanup.

If the scan result is not a valid ISBN, the UI should make that explicit and keep the user in the scanner rather than trying to guess.

Recommended copy direction:

- `This barcode doesn't look like a book ISBN.`

### Scan Completion

When a valid ISBN is captured:

1. stop or freeze the live scan session
2. show a loading state while the app resolves the book
3. transition into a confirmation surface instead of creating immediately

The scanner should not continue scanning in the background once a valid ISBN is captured.

## Lookup And Matching

### Backend Responsibility

Book matching logic should live on the Yamtrack side, not in the iOS app.

The client should send a normalized ISBN to a dedicated backend lookup path rather than treating ISBN as plain fuzzy search text. This keeps provider routing, normalization, and fallback behavior centralized and easier to evolve.

Expected backend responsibilities:

- normalize the ISBN consistently
- try supported book providers in a defined order
- return one of three result shapes:
  - single match
  - multiple plausible matches
  - no match

### Provider Order

Recommended provider resolution order:

1. `Open Library`
2. `Hardcover`

Reasoning:

- `Open Library` is a natural fit for ISBN-driven lookup
- `Hardcover` remains a useful fallback if the primary lookup misses or returns insufficient data

### Response Shape

The lookup response should return book candidates in the same conceptual format the app already expects from provider-backed add results:

- provider source
- provider media identifier
- title
- image
- any other lightweight display metadata already used in `Add Media`

This keeps confirmation UI close to the current provider result UI and avoids creating a second result model if existing structures can be extended cleanly.

## Confirmation UI

### Single Match

If lookup returns one strong result, the app should show a confirmation card instead of auto-adding.

Recommended content:

- cover image
- title
- provider label
- primary action: `Add Book`
- secondary action: `Scan Again`
- fallback action: `Search Manually` or return to the standard add screen

### Multiple Matches

If lookup returns multiple plausible results, the app should present a short result list first.

The user flow becomes:

1. choose the intended result
2. review the selected result
3. confirm creation

The app should not auto-select the first ambiguous match and pretend the result is certain.

### No Match

If lookup returns nothing, the UI should keep the user moving instead of dead-ending.

Recommended fallback actions:

- `Search manually`
- `Enter manually`
- `Scan again`

The app should prefill the scanned ISBN into the manual search field when sending the user into typed search, but the flow should not depend on fuzzy ISBN search working in every provider.

## Creation

Once the user confirms a provider result, the app should create the tracked media using the same provider-backed create request it already uses for book adds today.

This is a key design constraint:

- scanning changes discovery
- scanning does not introduce a new camera-specific create path

That keeps the feature small and lowers regression risk in the core creation logic.

## Error Handling

### Scanner Errors

The app should handle these cases explicitly:

- camera permission denied
- scanner unavailable on the current device or session state
- barcode found but not a valid ISBN
- user cancellation

Every scanner failure state should have a clear route back to the current `Add Media` book flow.

### Lookup Errors

If provider resolution fails because of API or connectivity issues:

- preserve the scanned ISBN if it helps for retry
- show a retry affordance
- offer manual search and manual entry as fallback actions

The feature should degrade into the existing add flow, not strand the user in a dead-end camera screen.

## Architecture

### iOS Responsibilities

The iOS client should own:

- barcode capture
- ISBN validation and lightweight normalization
- scanner presentation and dismissal
- lookup loading state
- confirmation UI state
- final create submission after confirmation

### Backend Responsibilities

The Yamtrack backend should own:

- ISBN normalization rules that must remain consistent across providers
- provider lookup order
- fallback behavior between `Open Library` and `Hardcover`
- returning candidate results in an app-friendly shape

### Existing Flow Reuse

The design should reuse the current app architecture wherever possible:

- `Add Media` remains the entry flow
- provider-backed creation remains unchanged
- existing result presentation patterns should be reused for confirmation unless the scanner needs a thin wrapper view for scan-specific actions

This feature should not introduce a second add stack with separate business rules.

## Testing Strategy

The feature should be implemented test-first in small slices.

Required iOS coverage:

- ISBN validation and normalization tests
- add-flow state tests for scan success, invalid ISBN, single match, multiple matches, no match, cancellation, and provider failure
- UI coverage for entering the scanner from `Add Media` when `Book` is selected
- UI coverage for confirming a scanned result before creation

Required backend coverage:

- ISBN lookup routing tests
- provider order and fallback tests
- response-shape tests for single match, multiple matches, and no match
- regression tests proving provider-backed creation still uses the existing path after confirmation

## Implementation Slices

### Slice 1: Scanner Entry And ISBN Handling

- add a `Scan Book Barcode` action to the `Book` add flow
- present the live barcode scanner
- validate and normalize scanned ISBN values
- handle invalid ISBN and cancellation states

### Slice 2: Backend ISBN Lookup

- add a dedicated ISBN lookup path on the backend
- normalize ISBN values centrally
- resolve against `Open Library` first and `Hardcover` second
- return candidate results in a shape the iOS app can render directly

### Slice 3: Confirmation UI

- add single-match confirmation
- add multiple-match selection and confirmation
- add no-match and lookup-failure fallback actions

### Slice 4: Final Create Integration

- submit the confirmed provider result through the existing create path
- refresh the library state after creation
- dismiss back into the normal app flow

## Open Questions Resolved

- V1 is book-only, not a general camera add feature
- A successful scan must still show confirmation before creation
- The scanner belongs inside the existing `Add Media` flow
- OCR and object recognition are deferred because barcode is the more reliable source of truth
- Non-book barcode support is deferred until there is a stronger resolver story
