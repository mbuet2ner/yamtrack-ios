# Yamtrack iOS Server Status Pill Design

## Summary

Replace the dedicated `Settings` tab with a server-status pill in the top-left of the library screen.

The pill should mirror the lightweight server affordance used in Prologue:

- green when the current Yamtrack server connection is available
- red when the app is disconnected or the saved session is no longer valid
- tappable in both states to open the existing connection form as a sheet

This change should keep the app single-server only. It should reuse the current setup UI rather than introducing multi-server management or a new server card design in this pass.

## Goals

- Make server connection status visible from the main app surface
- Let users reopen connection settings from a single obvious control
- Remove the need for a dedicated `Settings` tab
- Keep the signed-in shell available even when the session is disconnected
- Reuse the existing setup form and session controller instead of inventing a parallel settings flow

## Non-Goals

- Multi-server storage or switching
- A redesigned server-management sheet styled like Prologue's full server card UI
- Editing account/profile settings beyond server URL and token
- Background reachability polling beyond state changes already driven by app actions
- A third warning or loading state in the pill for v1

## Product Direction

The app should treat server connection as part of the main shell rather than a separate destination.

After session restoration completes, the user should remain in the regular app shell whether the stored session is valid or not. The library screen should expose a compact pill in the top-left corner that communicates current server availability and opens connection settings on tap.

This gives the app one consistent interaction model:

1. launch into the main shell
2. see current server status immediately
3. tap the pill to connect, reconnect, or inspect the current connection values

## Navigation

### Tabs

The signed-in shell should use two tabs:

- Library
- Add

The `Settings` tab should be removed.

### Connection Settings Presentation

The existing `SetupView` should be reused as a sheet presented from the root shell.

Tapping the server-status pill should present the sheet whether the app is connected or disconnected. The sheet should remain the single place to edit the server URL, update the token, and reconnect.

The app should not keep the current full-screen setup experience as the primary disconnected destination once session restoration has finished.

## Server Status Pill

### Placement

The pill should appear in the top-left region of the library screen, integrated into the header area rather than placed in the navigation bar chrome.

It should feel like a first-class control:

- capsule shape
- glassy styling that matches the current design system
- clear status dot on the leading edge
- short label text
- large enough tap target for reliable use

### States

The pill should support two user-visible states in v1:

- connected: green status dot
- disconnected: red status dot

Recommended copy:

- connected: show the current server host when short enough, otherwise a compact connected label
- disconnected: `Disconnected`

Exact copy can be finalized during implementation as long as the state difference stays obvious and compact.

### Behavior

Tapping the pill should always open the connection settings sheet.

The pill becomes the primary recovery path for:

- initial launch with invalid saved credentials
- expired sessions
- connection failures during library refresh
- deliberate logout

## Connection State Model

The current app mostly distinguishes between "has saved credentials" and "does not."

For this feature, the UI needs one higher-level connection state that the root shell and library header can consume.

### Required State

The app should expose a binary availability model for v1:

- connected: the app has a persisted session and the most recent credential validation or authenticated request succeeded
- disconnected: there is no persisted session, connection validation failed, the token is invalid, or an authenticated request proves the session is no longer valid

This state should remain owned by the session/root layer, not recomputed ad hoc inside the library view.

### State Transitions

- Successful restore of valid credentials: connected
- Restore of invalid or stale credentials: disconnected
- Successful connect from the sheet: connected
- Failed connect from the sheet: disconnected, while preserving the inline error in the sheet
- Authentication error during normal API use: disconnected
- Logout: disconnected and credentials cleared

## Screen Behavior

### Connected

When connected:

- the library behaves as it does today
- the server-status pill is green
- the add flow remains available from its existing tab

### Disconnected

When disconnected:

- the main shell still renders after restore completes
- the server-status pill is red
- the library can show its existing empty/error treatment as appropriate
- reconnecting happens from the pill's sheet, not by navigating to a separate settings area

The library does not need a fully custom disconnected redesign in this pass.

## Error Handling

The existing `SetupView` error handling should be preserved.

If connection attempts fail from the sheet:

- keep the sheet open
- retain entered values
- show the existing inline error message

If the library encounters an authentication failure:

- mark the connection state as disconnected
- update the pill to red
- point the recovery action to connection settings rather than a removed settings tab

Non-auth transient library failures may continue using the current retry behavior without forcing the pill into a new visual state beyond connected/disconnected.

## Reused Components

This design intentionally reuses:

- `SessionController` as the source of truth for credentials and connection changes
- `SetupView` and `SetupViewModel` for editing and submitting server URL and token
- the existing design system glass treatment for the new pill styling

This design intentionally does not add:

- a new server-management feature module
- a list of saved servers
- a second settings surface

## Testing Strategy

This feature should be implemented with test-first slices.

Required coverage:

- session/controller tests proving status changes on restore, connect success, connect failure, auth invalidation, and logout
- root-view or shell tests proving the `Settings` tab is removed and the app shell remains available in the disconnected state
- view tests or UI tests proving the server-status pill appears with connected and disconnected styling/text
- interaction coverage proving tapping the pill presents the connection sheet
- regression coverage for library auth failures now routing users to connection settings instead of a removed settings tab

## Implementation Slices

### Slice 1: Root Shell Restructure

- remove the `Settings` tab
- keep the main shell visible after session restoration regardless of connection availability
- host the connection sheet at the root level

### Slice 2: Connection State Exposure

- extend the session/root layer with a clear connected/disconnected state
- update restore, connect, logout, and auth-failure flows to drive that state consistently

### Slice 3: Library Status Pill

- add the top-left status pill to the library header
- bind pill styling and label to the connection state
- wire pill taps to present the connection sheet

### Slice 4: Error Path Cleanup

- replace any remaining `Open Settings` recovery paths with connection-sheet presentation
- confirm disconnected behavior is coherent across library empty, error, and expired-session flows

## Open Questions Resolved

- The feature should remain single-server only in this phase
- The pill should stay available as the main reconnection affordance even when disconnected
- The app should reuse the current setup form instead of introducing a richer server-management card
- Removing the `Settings` tab is part of the scope, not a follow-up task
