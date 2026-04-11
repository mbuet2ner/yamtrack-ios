# AGENTS Notes

## Upstream API Dependency

- This iOS client relies on the new Yamtrack API introduced in draft PR [FuzzyGrim/Yamtrack#924](https://github.com/FuzzyGrim/Yamtrack/pull/924).
- If API behavior looks incomplete or missing compared to the app, check that PR first before assuming the iOS client is wrong.
- Local testing against that API also requires a valid Yamtrack API token; the app cannot complete setup against the server without one.

## Yamtrack Backend Limitation

- The Yamtrack API currently accepts string provider `media_id` values on create, but its detail-style routes still only match numeric IDs.
- Example: `POST /api/v1/media/book/` works with `{"source":"openlibrary","media_id":"OL27448W","progress":0}`, but `GET /api/v1/media/book/openlibrary/OL27448W/` returns `404`.
- App-side workaround: the iOS client should avoid routing non-numeric provider items into detail/update screens until the backend route regexes are widened beyond `\\d+`.
