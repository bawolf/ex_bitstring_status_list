# Changelog

## Unreleased

- Rebuilt the package around the W3C Bitstring Status List Recommendation.
- Switched `encodedList` to multibase base64url of a GZIP-compressed bitstring with the 16KB privacy floor.
- Added Recommendation-shaped support for `statusSize`, `statusMessages`, `statusReference`, and `ttl`.
- Added `resolve_status/2`, normalized entry/result structs, and a compatibility layer for existing helper-style callers.
- Added a package `mix release.gate`.
- Replaced the old local-only fixture story with Recommendation-shaped released fixtures and updated docs.
