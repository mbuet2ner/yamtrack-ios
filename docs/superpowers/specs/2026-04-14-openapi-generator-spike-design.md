# OpenAPI Generator Spike Design

## Goal

Validate whether `apple/swift-openapi-generator` can be integrated into this repository cleanly enough to support future API client migration work.

This spike is intentionally limited to build-time integration. It should prove that generated client code can live in the repo and compile, without changing the app's existing handwritten API client.

## Current Context

- The app currently uses a small handwritten API layer in `YamtrackiOS/API/`.
- The repository already includes the backend OpenAPI document at `Yamtrack/openapi.yaml`.
- The API spec is broad and includes `oneOf` schemas plus some backend quirks around `media_id` typing and incomplete response modeling.
- The Xcode app is not currently organized as a Swift package, so generator integration should avoid destabilizing the main app target.

## Recommended Approach

Create a new local Swift package dedicated to the generator spike.

The package will:

- live inside the repository as an isolated package directory
- depend on `swift-openapi-generator`, `swift-openapi-runtime`, and `swift-openapi-urlsession`
- reference the existing `Yamtrack/openapi.yaml` document as the source of truth
- generate client code at build time using the package plugin
- expose a small generated client module that can be compiled independently of the app

The existing handwritten `APIClient` remains unchanged and continues to power the app.

## Package Shape

The spike package should contain:

- `Package.swift` with the generator/runtime/transport dependencies
- generator configuration files required by `swift-openapi-generator`
- a target that owns the generated client code
- a tiny test target or compile smoke target that imports the generated module and `OpenAPIURLSession`

The package should be local to the repo so that the spike can be removed or evolved later without entangling generated code directly into the Xcode app target.

## Verification

The spike is successful if all of the following are true:

- SwiftPM can resolve the generator-related package dependencies
- the generated client module builds successfully from the repository
- a minimal smoke test can compile code that instantiates the generated client transport stack

The smoke test does not need to perform any live network request. Its purpose is to prove integration, module visibility, and generated API surface availability.

## Expected Friction To Capture

During the spike, record concrete issues that affect future adoption, especially:

- how awkward or clean the generated API surface is for the endpoints we care about
- whether `oneOf` request or response bodies produce usable Swift types
- whether the current security scheme modeling maps cleanly to app auth needs
- whether incomplete or mismatched response schemas in the spec block generation or only affect future endpoint adoption

These findings are part of the spike output even if the package compiles successfully.

## Out Of Scope

This spike will not:

- replace the handwritten `APIClient`
- route any live app feature through generated code
- refactor app-facing DTOs such as `MediaSummary`, `MediaDetail`, or add-media models
- modify backend API behavior
- fix every OpenAPI schema issue found in the upstream document unless one is required to get the spike building

## Success Decision

If the spike builds cleanly and the generated surface looks reasonable, the next step can be a second spike that routes a single low-risk endpoint such as `info` through the generated client.

If the spike exposes major spec-quality or ergonomics issues, the repo should keep the handwritten client for now and treat generation as a future option gated on backend OpenAPI cleanup.
