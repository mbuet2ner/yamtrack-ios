# Yamtrack iOS Library Actions Design

## Summary

Refocus the current iOS app around a working library workflow:

- remove the broken Search tab
- fix tracked media updates from the detail screen
- add a real `Add Media` flow

This pass should keep the product small and reliable. The app should support provider-backed creation for top-level media types and keep manual creation as a fallback, without introducing direct season or episode creation in v1.

## Goals

- Remove non-working search affordances so the app only presents flows that work
- Let users update tracked progress and status from media detail
- Let users add new media for all top-level Yamtrack media categories
- Reuse the existing Yamtrack API surface instead of inventing app-specific backend behavior
- Keep the implementation small enough to ship in a few testable slices

## Non-Goals

- Direct season creation
- Direct episode creation
- Full web parity for advanced tracking fields
- Search as its own top-level app area
- Complex multi-step editor flows for edge-case media types

## Product Direction

The app should become library-first.

Instead of keeping a separate Search tab that does not work, the primary signed-in experience should be:

1. open the library
2. inspect tracked media
3. update a tracked item from detail
4. add something new from the library toolbar when needed

This keeps the information architecture simpler and makes creation feel like an action taken from the library, not a destination that competes with it.

## Navigation

### Tabs

The signed-in shell should use two tabs:

- Library
- Settings

The Search tab should be removed entirely.

### Add Entry Point

Library should gain a toolbar `Add` action using a standard plus icon. Activating it opens an `Add Media` sheet inside its own navigation context so the flow can push deeper screens if needed.

An empty-library state should also include an `Add Media` button so new users are not blocked.

## Add Media Flow

### Scope

The flow should support creation of these top-level media types:

- movie
- tv
- anime
- manga
- game
- book
- comic
- boardgame

Season and episode creation are deferred.

### Type and Source Rules

The UI should be type-first. After selecting a media type, the app should offer only the valid Yamtrack sources for that type.

Expected source mapping:

- movie: `tmdb` or `manual`
- tv: `tmdb` or `manual`
- anime: `mal` or `manual`
- manga: `mal`, `mangaupdates`, or `manual`
- game: `igdb` or `manual`
- book: `openlibrary`, `hardcover`, or `manual`
- comic: `comicvine` or `manual`
- boardgame: `bgg` or `manual`

### Provider Add

For provider-backed creation, the flow should:

1. choose media type
2. choose source
3. search provider results
4. select a result
5. confirm tracking details
6. create the tracked media

The app should use the Yamtrack search and create endpoints already supported by the backend. If a result is already tracked, the UI should indicate that clearly and avoid presenting it as a new add candidate.

### Manual Add

If the user chooses `manual`, the flow should switch from provider search to a compact manual form.

For v1 manual add, require only the fields needed for a valid creation:

- title
- optional image URL
- optional initial status
- optional initial progress
- optional score
- optional notes

The manual flow should still create a tracked media item through the same media-type creation endpoint.

### Success Handling

After a successful add, the sheet should dismiss, the new item should become visible in the library, and the app should be able to navigate to its detail screen if we already have enough response data to do so cleanly.

At minimum, the library list must refresh or insert the new item immediately.

## Media Detail Updates

### Problem

The current detail screen shows an update affordance but does not execute any action. This is especially visible for manual movies, where users expect progress or status updates to work.

### Detail Editing Direction

Replace the placeholder primary action with a real edit/update flow.

The detail screen should present a lightweight editor sheet that patches the tracked media item through:

- `PATCH /api/v1/media/{media_type}/{source}/{media_id}/`

The editor should support a narrow, practical set of fields:

- status
- progress
- score
- notes
- start date when already modeled cleanly in the client
- end date when already modeled cleanly in the client

If date editing would materially expand scope because of missing models or formatting work, it can be deferred from this pass. Status and progress are the required outcome.

### Save Behavior

On successful save:

- refresh media detail
- update the library list so the changed progress/status is visible immediately
- show a lightweight success state only if needed

On failure:

- preserve in-progress edits
- show a clear inline error

## API Client Changes

The iOS client layer should expand narrowly to cover:

- provider search for supported top-level media types
- media creation per type
- media patch/update per tracked item

The client should continue centralizing auth, request building, and API error mapping. New request bodies should be modeled explicitly rather than assembled ad hoc in views.

## State Management

To avoid stale UI after edits or adds:

- Library view model should own refresh logic and expose a way to merge or reload changed items
- Detail view model should save edits through the client and then reload its canonical detail payload
- Add flow state should stay isolated in its own feature module so canceling the sheet does not leak partial form state into Library

## Testing Strategy

This work should follow test-first changes in small slices.

Required coverage:

- API request tests for create, search, and patch endpoints
- view-model tests for add flow success and failure states
- view-model tests proving detail updates change state after save
- regression coverage for updating a manual movie
- UI or smoke coverage confirming Search is removed and Add is reachable from Library

## Implementation Slices

### Slice 1: Navigation Cleanup

- remove Search tab from the signed-in shell
- add Library toolbar `Add` action
- update empty state copy to point to Add instead of Search

### Slice 2: Update Tracked Media

- add patch request support to the API client
- add detail editor sheet and save flow
- refresh detail and library state after save

### Slice 3: Add Media

- add provider search support
- build top-level add flow with type-first source selection
- support manual fallback
- refresh library after creation

## Open Questions Resolved

- Add media should support provider-backed creation, not manual-only creation
- Provider-backed add should work across all top-level media categories using per-type source rules
- Season and episode creation are intentionally deferred to keep the first implementation manageable
