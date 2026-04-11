# Yamtrack iOS Design

## Summary

Build a native SwiftUI iPhone companion app for a single self-hosted Yamtrack server. The first release focuses on two primary jobs:

- viewing existing tracked media
- adding new media through type-first search

The app should feel simpler and more native than the web UI. It should use Apple's Liquid Glass direction through standard SwiftUI navigation, materials, search, sheets, and controls instead of recreating the desktop web layout.

## Goals

- Provide a fast, library-first mobile companion for an existing Yamtrack server
- Make it easy to inspect tracked media and perform quick progress updates
- Make adding new media straightforward with a type-first search flow
- Keep the first version small enough to implement in stable, testable slices
- Absorb API churn from the `feat/add-api` branch behind a narrow client layer

## Non-Goals

- Full feature parity with the web UI
- Multi-server support
- Offline-first sync
- Calendar, lists, recommendations, and statistics in v1
- Heavy custom glass effects that fight system behavior or readability

## Product Direction

The app is a companion, not a web app port. The web UI serves as a feature reference and a content model reference, but not a layout template.

The first version centers on this loop:

1. Launch into the library
2. Filter or inspect tracked media
3. Open a media detail screen
4. Perform a quick tracking update
5. Add new media through type-first search

## User Experience

### Setup and Authentication

The app supports one Yamtrack server per device in v1.

The setup flow asks for:

- base URL
- API token

The app validates the connection through `/api/v1/info/`, stores credentials securely, and enters the main app shell only after a successful validation.

Errors must be plain and actionable:

- invalid URL
- server unreachable
- invalid token
- unexpected server response

### Main Navigation

Top-level navigation uses a `TabView` with three tabs:

- Library
- Search
- Settings

Each tab owns its own `NavigationStack`.

This keeps the app iPhone-native and avoids translating the web app's desktop sidebar directly.

### Library

Library is the default landing screen. It should:

- load quickly
- show tracked media immediately
- support filtering by media type
- support refresh
- handle loading, empty, and error states gracefully

The presentation can be a dense list or card-based layout, but it should prioritize readability and progress visibility over decorative chrome.

### Media Detail

Media detail is action-first.

The top section should prioritize:

- current status
- progress
- the next meaningful tracking action
- quick edits for score, status, progress, and dates where supported

Below that, the screen can show:

- summary metadata
- artwork
- tags or genres
- supporting details

For TV, the hierarchy should stay compact and intuitive:

- show detail
- season list
- episode list or episode detail as needed

The app should not dump all seasons and episodes onto the first detail screen.

### Add Media

The add flow starts in Search.

The user first chooses a media type, then searches provider-backed results for that type, then adds the selected result to their tracked library.

If a result is already tracked, the UI should make that clear and avoid presenting it like a new add.

### Settings

Settings should stay minimal in v1 and include:

- base URL
- connection status
- app/server version display
- retry connection test
- logout/reset local credentials

## Visual Direction

The app should be visually distinct from the web UI while staying clearly "Yamtrack."

### Liquid Glass Principles

Use system-native SwiftUI controls and containers so the platform can supply Liquid Glass behavior automatically where appropriate.

Prioritize:

- standard navigation bars
- tab bars
- search fields
- filter chips or segmented controls
- sheets
- toolbars

Avoid:

- full-screen frosted overlays for ordinary content
- stacking multiple translucent layers unnecessarily
- sacrificing contrast or information density for visual effect

### Visual Character

The visual style should be distinctive but practical:

- restrained material usage
- strong readability
- subtle depth and motion
- clean surfaces for content
- selective color accents derived from artwork or media type

The result should feel closer to a polished Apple-native utility than a theatrical glass concept app.

## Technical Architecture

### App Layers

The app should be organized into small, focused layers:

- `App`: bootstraps session state and root navigation
- `Session`: owns base URL, token, and connection/auth state
- `APIClient`: builds requests, applies auth, decodes responses, maps errors
- `Features`: isolated modules such as `Library`, `Search`, `MediaDetail`, and `Settings`
- `DesignSystem`: materials, spacing, reusable surfaces, and control styling
- `Models`: `Codable` types for only the API payloads the app actually uses

### Boundary Rules

- Views should depend on feature-facing view models, not raw endpoint logic
- Networking and payload adaptation should stay behind the API layer
- UI state should be derived from small view models that are easy to test
- The initial model surface should stay narrow to reduce risk from backend schema changes

## API Strategy

The backend lives in the checked-out Yamtrack repository on the `feat/add-api` branch, and the OpenAPI document exists at `Yamtrack/openapi.yaml`.

The iOS app should not attempt to support the entire API surface in v1. It should implement a narrow client around the endpoints needed for the first release:

- `/api/v1/info/`
- `/api/v1/media/`
- relevant media detail routes
- relevant media update routes
- `/api/v1/search/{media_type}/`

The API layer should:

- centralize auth header handling
- normalize API and transport errors into app-level errors
- decode only fields needed by current screens
- tolerate additive schema changes where practical

## v1 Scope

### In Scope

- setup/auth with base URL and token
- secure credential storage
- connection validation
- library screen with media type filtering
- media detail screen
- quick progress update flow
- TV seasons and episodes drill-down
- type-first add-media search flow
- basic settings and diagnostics

### Deferred

- calendar
- lists
- statistics
- recommendations
- advanced history editing
- offline caching and conflict handling
- multi-server support

## Testing Strategy

Testing should stay close to each work package and focus on fast feedback:

- unit tests for request construction and decoding
- view-model tests for loading, success, empty, and error states
- fixture-based previews or mocks for UI development
- a small number of UI smoke tests for key flows
- manual end-to-end verification against a running Yamtrack instance before calling v1 usable

## Work Packages

### 1. Project Bootstrap

#### Outcome

A runnable SwiftUI iOS app shell with tabs, navigation, and design-system scaffolding.

#### Acceptance Criteria

- The app launches successfully in the simulator
- A root shell exists with initial `Library`, `Search`, and `Settings` tabs
- Navigation stacks are wired for each tab
- Design-system tokens and reusable material helpers compile and render in previews

#### Red Test

- No app target or root shell exists
- The app cannot build or launch with a stable root navigation structure

#### Green Test

- The app builds cleanly
- A UI smoke test confirms the root shell renders with the expected tabs

### 2. Server Setup and Secure Session Storage

#### Outcome

The user can enter a base URL and token, validate them, and persist them securely.

#### Acceptance Criteria

- A valid server and token pass connection validation through `/api/v1/info/`
- Invalid URL and invalid token errors are shown with actionable messages
- Credentials persist across relaunch
- Logout clears persisted credentials and returns the app to setup

#### Red Test

- There is no working setup flow
- Session storage does not persist or clear correctly
- Connection validation is absent or unreliable

#### Green Test

- Unit tests pass for session persistence and clearing
- Unit tests pass for connection validation success and failure
- A UI test covers the happy path and an invalid-token path

### 3. Shared API Client Foundation

#### Outcome

A typed networking layer handles request building, auth, decoding, and error mapping.

#### Acceptance Criteria

- Requests include the correct auth header format
- Supported endpoint requests are built correctly
- Transport and API errors map into stable app-level error cases
- Fixture payloads decode successfully for the initial supported endpoints

#### Red Test

- Requests omit or misapply auth headers
- Request paths or query encoding are incorrect
- Fixture payloads fail to decode for supported endpoints

#### Green Test

- Unit tests pass for `/api/v1/info/`, `/api/v1/media/`, and search request construction
- Unit tests pass for decoding representative success and error fixtures

### 4. Library Screen

#### Outcome

The app displays tracked media with media-type filtering and stable loading states.

#### Acceptance Criteria

- Library data loads from the server
- The user can filter by media type
- Pull-to-refresh reloads the library
- Loading, empty, and error states are distinct and usable
- Tapping an item opens its detail screen

#### Red Test

- The library view model cannot load data or apply filtering correctly
- The screen cannot represent empty or failure states predictably

#### Green Test

- View-model tests pass for loading, filtering, empty, and error transitions
- A UI smoke test verifies the list renders and filter changes update the content

### 5. Media Detail Screen

#### Outcome

An action-first detail screen renders a tracked item and exposes its primary tracking controls.

#### Acceptance Criteria

- Detail data loads for a tracked item
- The screen shows key metadata and current tracking state
- Primary tracking controls are visible near the top
- Failure states are recoverable through retry

#### Red Test

- The detail model cannot be loaded into a stable display state
- Primary actions are not exposed from the loaded state

#### Green Test

- Fixture-driven tests pass for detail state mapping
- UI smoke verification confirms key fields and primary controls render

### 6. Quick Progress Update Flow

#### Outcome

The user can perform the primary tracking action directly from detail.

#### Acceptance Criteria

- Progress or status updates build the correct request payload
- A successful update refreshes or mutates the visible state immediately
- Failures show recoverable feedback without corrupting state

#### Red Test

- The update action builds an incorrect request
- The view model fails to represent in-flight, success, and failure transitions

#### Green Test

- Request tests validate PATCH payload construction
- View-model tests validate optimistic or post-success state transitions and rollback/failure behavior

### 7. TV Seasons and Episodes Flow

#### Outcome

TV items can drill into seasons and episodes with focused tracking actions.

#### Acceptance Criteria

- TV detail exposes season navigation when relevant
- Season lists load correctly
- Episode lists or episode detail screens are reachable
- Quick progress actions work where the API supports them

#### Red Test

- TV hierarchy payloads cannot be mapped into season and episode screens
- Navigation cannot represent the drill-down structure consistently

#### Green Test

- Fixture-based tests pass for TV hierarchy mapping
- A UI smoke test confirms show-to-season-to-episode navigation

### 8. Add-Media Search Flow

#### Outcome

The user can choose a media type, search provider-backed results, and add a new tracked item.

#### Acceptance Criteria

- The user selects a media type before searching
- Search results render for that type
- The user can add a result successfully
- Already tracked results are clearly indicated

#### Red Test

- Search request construction or result decoding fails
- Add actions cannot be triggered or do not update UI state correctly

#### Green Test

- Unit tests pass for search request and add request construction
- View-model tests pass for empty, loaded, already-tracked, and add-success states
- A UI smoke test confirms the core type-select, search, and add flow

### 9. Settings and Diagnostics

#### Outcome

A minimal settings screen exposes connection information and credential reset behavior.

#### Acceptance Criteria

- Settings displays base URL and version information when available
- The user can rerun a connection test
- The user can clear credentials and return to setup

#### Red Test

- Settings has no stable binding to session and server state
- Reset and retry actions are missing or unreliable

#### Green Test

- Unit tests pass for settings state behavior
- A UI smoke test confirms retry and logout/reset behavior

### 10. Polish and Release Hardening

#### Outcome

The app has a cohesive visual finish, baseline accessibility, and verified core flows.

#### Acceptance Criteria

- Material usage is consistent and restrained
- Dynamic type and contrast remain usable
- Core setup, library, detail, and add flows work against a live Yamtrack server

#### Red Test

- Accessibility labels are missing from core controls
- Material layering harms readability
- One or more core live flows are broken

#### Green Test

- Accessibility checks pass for core screens
- Manual verification passes for setup, library, detail, and add flow on a live server

## Risks and Mitigations

### API Churn

Risk: the backend branch is still changing.

Mitigation:

- keep endpoint coverage narrow
- isolate payload handling in the API layer
- use fixture tests that can be updated intentionally as the backend evolves

### Over-Designing the First Release

Risk: trying to match the web app too closely will slow delivery and weaken the iOS experience.

Mitigation:

- keep the top-level app shape to three tabs
- stay focused on viewing, adding, and quick updates
- defer secondary features deliberately

### Glass Overuse

Risk: a "liquid glass" interpretation can reduce readability and increase implementation complexity.

Mitigation:

- rely on system materials first
- reserve custom styling for a few high-value surfaces
- test contrast and density early

## Open Decisions Resolved

The following decisions are intentionally fixed for the first implementation plan:

- single self-hosted server per device
- library-first home screen
- type-first search for adding media
- action-first media detail
- distinctive but practical Liquid Glass styling
- focused companion scope instead of broad feature parity

## Next Step

After review and approval of this design document, the next step is to create a detailed implementation plan from these work packages.
