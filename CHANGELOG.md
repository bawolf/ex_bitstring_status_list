# Changelog

All notable changes to `ex_bitstring_status_list` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project intends to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-03-12

### Added
- Rebuilt the package around the W3C Bitstring Status List Recommendation.
- Switched `encodedList` to multibase base64url of a GZIP-compressed bitstring with the 16KB privacy floor.
- Added Recommendation-shaped support for `statusSize`, `statusMessages`, `statusReference`, and `ttl`.
- Added `resolve_status/2`, normalized entry/result structs, and a compatibility layer for existing helper-style callers.
- Added a package `mix ex_bitstring_status_list.release.gate`.

### Changed
- Replaced the old local-only fixture story with Recommendation-shaped released fixtures and updated docs.
