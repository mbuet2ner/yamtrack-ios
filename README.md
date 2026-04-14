# yamtrack-ios

An iOS client for Yamtrack with a glassy, library-first interface for browsing, adding, and updating media.

## API Note

- This app currently relies on the new Yamtrack API from draft PR [FuzzyGrim/Yamtrack#924](https://github.com/FuzzyGrim/Yamtrack/pull/924).
- To connect the app to a local or self-hosted Yamtrack instance, you also need a valid Yamtrack API token.

## Future Work

- [ ] Autogenerate API client
  - [x] Validate whether [apple/swift-openapi-generator](https://github.com/apple/swift-openapi-generator) can generate a usable client for Yamtrack in a spike branch (`codex/openapi-generator-spike`)
  - [ ] Possible, but not a good fit right now because the API and OpenAPI document are still evolving
  - [ ] The spike found a few quirks that the current handwritten client already smooths over manually
    - mixed `media_id` typing between provider creates and detail-style routes
    - incomplete response modeling for some routes, especially update flows

## Branding

<p align="center">
  <img src="docs/branding/png/yamtrack-mark.png" alt="Yamtrack app icon mark" width="148" />
</p>

<p align="center">
  <img src="docs/branding/png/yamtrack-logo.png" alt="Yamtrack logo" width="320" />
</p>

## Screenshots

<p align="center">
  <img src="docs/screenshots/library.png" alt="Library screen" width="240" />
  <img src="docs/screenshots/add-media.png" alt="Add media screen" width="240" />
  <img src="docs/screenshots/settings.png" alt="Settings screen" width="240" />
</p>
