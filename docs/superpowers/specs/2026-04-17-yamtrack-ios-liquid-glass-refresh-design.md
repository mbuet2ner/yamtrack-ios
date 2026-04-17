# Yamtrack iOS Liquid Glass Refresh

## Summary

Refresh the Yamtrack iOS app so it adopts Apple-style Liquid Glass more intentionally across the shell and key controls.

The redesign should:

- raise the deployment target to `iOS 26`
- replace the current frosted-card-heavy look with real Liquid Glass on the functional layer
- remove the top-level `Add` tab and replace it with a separate floating glass add orb
- move the server / localhost indicator into a floating glass control in `Library`
- support native light mode and dark mode by relying on system surfaces instead of custom gradients
- redesign media status and progress pills so they feel more elegant and more system-native
- reduce custom backgrounds and chrome that interfere with standard navigation and bar behavior

This is an app-wide visual and structural refresh. The goal is not "more blur"; it is a cleaner hierarchy that feels closer to current Apple apps.

## Goals

- Adopt real Liquid Glass APIs where they improve navigation and control affordances
- Preserve content readability by keeping large content regions mostly on native system surfaces
- Make `Library` feel lighter and less boxed in
- Turn `Add Media` into a cleaner, more native control flow
- Improve consistency across `Library`, `Add Media`, media detail, setup, and app shell
- Let system components handle more appearance automatically in light mode, dark mode, and accessibility-adaptive settings

## Non-Goals

- Reworking API behavior or data models unrelated to UI presentation
- Redesigning the entire information architecture of the app
- Converting every card and panel into Liquid Glass
- Introducing highly custom animations that compete with Apple’s system motion language
- Back-deploying the new design to earlier iOS versions

## Current Problems

The current UI uses custom material cards and gradients in a way that feels closer to older frosted iOS treatments than to current Apple interfaces.

Specific issues:

- `Library` places server status, title, count, filter, and add actions inside a single heavy control card
- the top-level `Add` tab duplicates a creation path that could be handled as a floating utility action
- screen backgrounds depend on custom gradients instead of native system surfaces
- large portions of the app use similar glass-like cards, which weakens hierarchy
- status and progress pills in media rows are visually generic and heavier than they need to be
- detail and setup screens use more custom surface treatment than is necessary
- custom background styling risks fighting system bar, toolbar, and scroll-edge behavior

## Product Direction

The app should use Liquid Glass as a distinct functional layer.

That means:

- navigation and utility controls can be glass
- grouped filters and small semantic controls can be glass
- large content surfaces should generally stay clean and readable
- background styling should become subtle enough that light mode and dark mode feel native

The interface should feel calmer, more spatial, and more Apple-like, with fewer oversized boxes and less decorative blur.

## Final Experience

### App Shell

The app shell should become simpler and more native:

- `Library` remains the main navigation destination
- `Add Media` is opened via a floating glass add orb near the bottom navigation region
- the orb should feel like a utility control, not a second tab
- bottom navigation chrome should be lighter and handled by standard system components as much as possible

The shell should avoid a giant custom frosted slab under all controls. The system bar should do most of the work, while the add orb provides the one intentionally prominent custom affordance.

### Library

The `Library` screen should:

- remove the embedded `Add` action from the top control area
- move the server / localhost control into a floating glass element above the content
- simplify the header so the title and count are readable without feeling duplicated or boxed in
- keep filtering available, but present it as a lighter grouped control

The page should rely mostly on native background surfaces. The screen should feel open and content-led rather than card-led.

### Media Rows

Media rows should stay content-first:

- artwork remains a strong visual anchor
- title and media type remain readable and compact
- status and progress should become refined semantic chips instead of generic capsules

The chips should:

- use quieter sizing and spacing
- use status-aware tinting sparingly
- feel like metadata, not mini buttons
- remain legible in light mode, dark mode, and reduced-transparency contexts

### Add Media

`Add Media` should lean on grouped functional controls instead of stacking many peer glass cards.

The screen should:

- use glass for the most important interactive controls only
- keep results mostly on clean content surfaces
- avoid oversized hero styling
- keep the bottom action area lighter and more native

Type, source, and search controls should feel related and intentionally grouped. Results should stay subordinate to the control layer.

### Media Detail

The detail screen should:

- reduce large custom frosted sections
- rely more on standard navigation, toolbar, and sheet patterns
- keep editing actions easy to discover without overframing them
- use cleaner metadata presentation that matches the refreshed library style

### Setup / Connection

The setup flow should lean on standard forms, sheets, and toolbars so it inherits Liquid Glass and system adaptation automatically.

This screen does not need heavy custom treatment.

## Liquid Glass Principles

### Use Standard Components First

Where SwiftUI already provides native behavior, prefer that over custom backgrounds or wrappers.

Relevant areas include:

- `NavigationStack`
- `TabView` / `Tab`
- toolbars
- sheets
- forms
- popovers

### Apply Liquid Glass Sparingly

Use Liquid Glass for:

- the floating add orb
- grouped bottom utility / navigation-adjacent controls when needed
- the floating server status control
- small grouped controls such as filters or source selectors
- small semantic chips where glass meaningfully improves the hierarchy

Avoid applying Liquid Glass to every large card, every row background, and every empty state.

### Remove Competing Custom Backgrounds

Custom gradients and explicit card backgrounds should be reduced or removed from:

- screen-level backgrounds
- navigation-adjacent regions
- toolbars
- tab bar surroundings
- large container cards that only exist to create a frosted effect

### Group Glass Intentionally

When several glass controls appear together, wrap them in `GlassEffectContainer` and use aligned spacing so the effects blend consistently.

Important candidates:

- bottom navigation region plus floating add orb
- library filter / status controls
- add media control clusters

### Keep Modifier Order Correct

Apply `glassEffect` after layout and appearance modifiers that define the view’s size and content. This ensures the system captures the final shape and content correctly.

## SwiftUI Structure

Recommended structural changes:

- replace the old `GlassSurface` pattern with iOS 26-aware shared primitives
- separate "functional glass" views from "content surface" views
- extract small reusable chips and floating controls instead of one generic frosted container
- use the modern `Tab` API instead of legacy `.tabItem` where possible

The redesign should make the main views easier to read by expressing visual roles clearly:

- shell / navigation
- floating utility controls
- content surfaces
- metadata chips

## Accessibility and Adaptation

The redesign must be verified against:

- light mode
- dark mode
- Reduce Transparency
- Reduce Motion
- larger Dynamic Type sizes
- increased contrast

Custom glass controls should still look intentional when the system reduces translucency or motion.

Animations should be purposeful and limited, focusing on spatial continuity rather than decorative motion.

## Implementation Plan

### Shared Design System

- add iOS 26-aware glass primitives for controls and grouped glass regions
- add clean content-surface styling for larger cards that should not be glass
- add reusable semantic metadata chips for status and progress

### App Shell

- raise the deployment target to `iOS 26`
- simplify the main tab shell
- remove the dedicated `Add` tab
- add a floating glass add orb that presents the add flow

### Library

- move server status into a floating glass control
- remove top-level add action
- simplify title and filter presentation
- replace heavy background styling with native surfaces

### Media Rows

- refresh row spacing and framing
- redesign status and progress pills
- reduce unnecessary border and shadow treatment

### Add Media

- convert important control groups to native glass
- reduce the number of large boxed sections
- keep results cleaner and less material-heavy

### Media Detail and Setup

- remove unnecessary custom surface styling
- rely more on standard sheets, forms, and toolbar behavior

## Testing Strategy

The refresh is mostly visual, but it should still be validated with code and runtime verification where practical.

Required validation:

- unit tests for extracted presentation helpers or state derivation introduced by the redesign
- successful project build after moving to `iOS 26`
- manual verification of the refreshed screens in both light mode and dark mode
- spot checks for reduced transparency and reduced motion behavior

## Risks

- overapplying Liquid Glass could make the interface noisier instead of cleaner
- custom floating controls can easily feel non-native if spacing or sizing is off
- removing too many supporting surfaces could reduce clarity if hierarchy is not rebuilt carefully
- existing in-progress edits in `AddMediaView` require careful integration rather than replacement

## Recommendation

Implement the redesign from shared primitives outward:

1. shared glass and content-surface primitives
2. app shell and floating add orb
3. library header and media rows
4. add media controls
5. detail and setup cleanup

This sequence keeps the visual language consistent and reduces the risk of half-migrated styling.
