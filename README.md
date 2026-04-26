<p align="center">
  <img src="yamtrack-ios-logo.png" alt="Yamtrack app icon mark" width="132" />
</p>

An (unofficial) iOS client for [Yamtrack](https://github.com/FuzzyGrim/Yamtrack) with a library-first interface for browsing, adding, and updating media.

## 🔌 API Note

- This app targets the Yamtrack API on the upstream [`feat/add-api`](https://github.com/FuzzyGrim/Yamtrack/commits/feat/add-api) branch.
- API request routing is generated from the checked-in schema snapshot in `YamtrackOpenAPI`, whose source of truth is Yamtrack's `/api/schema/` endpoint.
- To connect the app to a local or self-hosted Yamtrack instance, you need a valid Yamtrack API token.

## 🛠️ Local Setup

1. Clone this repository and open the Xcode project:

   ```bash
   git clone https://github.com/FuzzyGrim/yamtrack-ios.git
   cd yamtrack-ios
   open YamtrackiOS.xcodeproj
   ```

2. Clone the Yamtrack backend in a separate directory, then check out the API branch used by the iOS app:

   ```bash
   git clone https://github.com/FuzzyGrim/Yamtrack.git
   cd Yamtrack
   git checkout feat/add-api
   ```

3. Start the local API:

   ```bash
   docker compose -f docker-compose.local-api.yml up --build
   ```

4. Open [http://localhost:8000](http://localhost:8000), create an account or sign in, then copy your API token from `Settings > Integrations`.

5. Run the iOS app from Xcode and enter these values on the `Connect` screen:
   - `Server URL`: `http://localhost:8000`
   - `API Token`: the token you copied from Yamtrack

## 🧭 Future Work

- [x] Generate API request routing from Yamtrack's OpenAPI schema with [apple/swift-openapi-generator](https://github.com/apple/swift-openapi-generator).
- [ ] Continue narrowing app-side DTO mapping as the upstream schema models response bodies more precisely, especially update flows.

## 📸 Screenshots

<p align="center">
  <img src="docs/screenshots/library.png" alt="Library screen" width="220" />
  <img src="docs/screenshots/library-t.png" alt="Library screen scrolled to T" width="220" />
  <img src="docs/screenshots/add-media.png" alt="Add media screen" width="220" />
</p>

<p align="center">
  <img src="docs/screenshots/tracking.png" alt="Tracking editor" width="220" />
  <img src="docs/screenshots/settings.png" alt="Connection screen" width="220" />
</p>
