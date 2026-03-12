# Interop Notes

`ex_bitstring_status_list` is currently scoped to Recommendation-shaped
status-list semantics rather than a dedicated TS/Rust recorder harness.

## Current Evidence

- released fixture corpus under `test/fixtures/upstream/released/`
- golden credential fixtures under `test/fixtures/golden/`
- W3C Recommendation examples used as deterministic fixture inputs
- direct unit tests for entry parsing, encoding, credential round-tripping, and
  status resolution

## Boundary Rules

- `ex_bitstring_status_list` owns status-list entry and credential semantics
- `ex_vc` owns generic VC field validation and proof boundaries
- `ex_did` owns DID resolution
- `ex_openid4vc` owns protocol transport and wallet/verifier envelopes

## Current Sources Of Truth

- W3C Recommendation: `vc-bitstring-status-list`
- W3C interoperability report / test suite
- package-owned deterministic fixtures for behavior not directly represented in a reusable external oracle

## Claim Policy

Do not claim cross-language parity for a new behavior unless the package has a
committed released fixture for it and the owning README/test/docs are updated in
the same workstream.
