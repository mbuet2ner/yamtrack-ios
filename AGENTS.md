# AGENTS Notes

## Yamtrack Backend Limitation

- The Yamtrack API currently accepts string provider `media_id` values on create, but its detail-style routes still only match numeric IDs.
- Example: `POST /api/v1/media/book/` works with `{"source":"openlibrary","media_id":"OL27448W","progress":0}`, but `GET /api/v1/media/book/openlibrary/OL27448W/` returns `404`.
- App-side workaround: the iOS client should avoid routing non-numeric provider items into detail/update screens until the backend route regexes are widened beyond `\\d+`.
