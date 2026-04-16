# Add Media Progressive Redesign

## Summary

Redesign the iOS `Add Media` screen so it behaves like a progressive task flow instead of a dashboard of peer sections.

The new screen should:

- show media type as the first and only initial choice
- reveal provider-backed search only after a type is chosen
- auto-select the most likely provider for that type while still allowing source switching
- hide results entirely until the user explicitly runs a search
- keep result selection inline instead of duplicating it in a separate summary card
- move manual entry into a separate sheet
- keep the add screen open after success so the user can continue adding more items

This redesign is primarily a workflow and hierarchy change. It should reduce visual clutter, remove overlapping empty states, and feel closer to a native iOS utility flow.

## Goals

- Reduce the number of simultaneously visible controls and surfaces on `Add Media`
- Make the next action obvious at every step
- Preserve provider-backed add for all top-level media types
- Keep manual add available without letting it complicate the default discovery flow
- Remove duplicated selection UI between result cards and the bottom action area
- Use modern SwiftUI structure with a small number of explicit UI states

## Non-Goals

- Changing supported media types or supported provider mappings
- Reworking API request or creation behavior beyond what the new flow requires
- Adding advanced provider configuration
- Turning `Add Media` into a multi-screen wizard for provider-backed search
- Adopting Liquid Glass broadly across the screen

## Current Problems

The current `Add Media` view renders type, source, search, results, selected-result confirmation, error state, and bottom action as separate peer sections. This creates a dashboard-like screen with too many competing boxes.

Specific issues:

- type and source are both shown up front, which makes setup feel heavier than it is
- search and results occupy space even before the user has committed to a search
- the empty-results state visually collides with the surrounding results container and bottom action area
- selected result appears in both the results list and a separate `Ready To Add` card
- manual entry shares the same visual structure as provider search even though it is a different task
- glass/material treatment is spread across too many surfaces, which increases visual noise instead of clarifying hierarchy

## Product Direction

The screen should feel like a single progressive funnel:

1. choose a media type
2. search the default provider for that type
3. optionally switch provider
4. inspect results
5. select one result
6. add it

Manual entry should remain available, but it should branch into its own sheet instead of transforming the main screen into a different form.

The user should only ever feel one primary next step.

## Final Experience

### Initial State

On first open, the screen should show:

- navigation title
- a short supporting line that explains the task
- the media type picker
- the bottom action area in its disabled, instructional state

No media type should be preselected on first open. The user should make an explicit type choice before the search composer appears.

The provider switcher, search field, results list, and manual form should not be visible yet.

### After Media Type Selection

Selecting a media type reveals a single search composer area.

The screen should automatically select the default provider for the chosen type:

- movie: `tmdb`
- tv: `tmdb`
- anime: `mal`
- manga: `mal`
- game: `igdb`
- book: `openlibrary`
- comic: `comicvine`
- boardgame: `bgg`

The query text should be preserved if the user changes media type later. Existing results and any selected result should be cleared when the context changes.

Changing media type should not automatically run a new search.

### Search Composer

The search composer is the main grouped surface on the screen.

It should contain:

- a compact provider control inside the composer, not in its own section
- the search text field
- the search action
- one short helper line when no search has been run yet

The provider control should default to the primary provider for the selected type but allow switching to any other supported provider for that type. A compact `Menu`-style control is the preferred presentation because it keeps the default path light while still exposing alternatives.

If the user chooses `Manual` from this control, the app should present a separate manual-entry sheet instead of replacing the composer in place.

### Results

Results should remain fully hidden until the user actively runs a search.

After search:

- if matches exist, show the results list below the composer
- if there are no matches, show one inline empty state below the results heading
- if the request fails, show one inline error state that preserves the current query

There should be no placeholder results section before first search.

### Result Selection

Tapping a result should select it inline within the results list.

There should be no separate `Ready To Add` card.

The selected result row should communicate selection through a stronger background/border treatment and a concise selected affordance. Non-selected rows should remain visually lighter than the current card treatment so the list reads as scan-first content rather than a stack of tiles.

Already tracked items should remain non-addable and clearly labeled as already tracked.

### Bottom Action Area

The bottom action area should persist throughout the flow and behave like a native action region rather than another card.

It should show:

- a short title that reflects the current step
- one line of supporting text
- the primary action button

Behavior:

- before type selection or before a provider result is selected, the button stays disabled and the subtitle explains what is missing
- after a result is selected, the subtitle can show the selected title
- after successful add, the button should not immediately dismiss the screen

This area should summarize state, not duplicate the full result UI.

### Manual Entry

Manual entry should open in a separate sheet.

That sheet can continue using a compact manual form, but it should be scoped to manual creation only. Dismissing the sheet should return the user to the current `Add Media` context without disturbing the chosen type or search query.

### Success Behavior

After a successful add:

- keep the add screen open
- show lightweight success feedback
- keep the user in the current add flow so they can continue adding more items

Success feedback should be non-blocking. Good outcomes include a transient confirmation message, a success banner, or a short success state in the bottom action area.

After success, the screen should clear the selected provider result so the user does not accidentally add the same item twice. The existing query may remain so the user can refine or repeat nearby searches.

## Visual Direction

The redesign should be quieter and more native than the current screen.

### Hierarchy

- Type picker is the first focal point
- Search composer is the primary grouped surface once type is chosen
- Results are secondary content
- Bottom action is stable and utilitarian

### Density

- reduce the number of distinct cards
- prefer spacing and typography over repeated boxed sections
- avoid large decorative hero treatment once the flow becomes active

### Liquid Glass / Material

Use glass or material sparingly:

- acceptable on the search composer
- acceptable on the bottom action area
- avoid applying glass to every chip, every result row, and every empty state

If iOS 26-specific glass APIs are adopted, they must be availability-gated with fallback materials on earlier OS versions.

### Empty States

Before first search, use a helper line inside the composer instead of a large empty placeholder.

After search with zero results, use one compact inline empty state beneath the results header. It should not visually overlap with the bottom action area.

## SwiftUI Structure

This redesign should simplify view composition around a small set of explicit states instead of a long stack of independent sections.

Recommended view states:

- no type chosen yet
- type chosen, ready to search
- searching
- searched with results
- searched with empty state
- searched with error
- result selected
- showing manual sheet
- showing transient success feedback

Recommended structural changes:

- remove the separate `selectedResultCard`
- replace the always-visible `sourceSection` and `searchSection` with one conditional composer
- gate results rendering on whether the user has run a search, not just whether `results.isEmpty`
- keep bottom action logic centralized so the visible title, subtitle, and button state derive from the same state machine

The search composer and results list should be extracted into focused subviews so the main view body stays easy to read and diff.

## State and Behavior Notes

- Query text should survive media type changes
- Switching media type should re-resolve the default provider if the old provider is no longer valid
- Switching provider should clear old results and selected result
- Running search with an empty query should not reveal results UI
- Selecting `Manual` should launch the manual sheet and leave the main add screen intact
- Successful add should refresh library state the same way the existing add flow does

## Testing Strategy

Required coverage for this redesign:

- view-model coverage for preserving `query` across media type changes
- coverage for resetting results and selection when type or provider changes
- UI coverage proving results are not shown before first search
- UI coverage proving a selected provider result enables the add action without a separate selected-result card
- UI coverage proving choosing `Manual` opens the separate sheet
- UI coverage or smoke coverage proving success keeps the add screen open for continued adding

## Resolved Decisions

- media type is the first visible choice
- the most likely provider is auto-selected for the chosen type
- alternate providers remain available inside the search composer
- results appear only after explicit search
- selected result stays inline in the list
- query text is preserved across media type changes
- manual entry opens in a separate sheet
- success keeps the user in the add flow instead of dismissing immediately

## Implementation Notes

This design can be implemented as a targeted redesign of the existing `AddMediaView` and `AddMediaViewModel` rather than a new feature module.

The main product shift is not additional capability. It is a narrower presentation that reveals the same capability in a cleaner order.
