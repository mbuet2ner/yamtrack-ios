# AGENTS Notes

## Upstream API Dependency

- This iOS client targets the stable Yamtrack API on the upstream [`feat/add-api`](https://github.com/FuzzyGrim/Yamtrack/commits/feat/add-api) branch.
- Treat Yamtrack's `/api/schema/` endpoint as the source of truth. The checked-in `YamtrackOpenAPI` package contains a schema snapshot used by `swift-openapi-generator`.
- If API behavior looks incomplete or missing compared to the app, compare the checked-in schema snapshot with a current `feat/add-api` server before assuming the iOS client is wrong.
- Local testing against that API requires a valid Yamtrack API token; the app cannot complete setup against the server without one.

## Provider Media IDs

- Detail and update routes on `feat/add-api` accept string `media_id` path values, including provider IDs such as Open Library's `OL27448W`.
- Do not reintroduce app-side numeric-only guards for provider media IDs.
