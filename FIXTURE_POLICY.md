# Fixture Policy

`ex_bitstring_status_list` ships its released fixture corpus in-repo.

## Contract Levels

- `test/fixtures/upstream/released/` is contractual
- `test/fixtures/upstream/main/` is reserved for future advisory drift detection
- `test/fixtures/golden/` contains deterministic examples used by docs and tests

## Runtime Boundary

Normal library usage and normal `mix test` do not require Node, Rust, Cargo, or
network access.

## What Gets Committed

Commit:

- released fixture manifests and cases
- golden fixtures used by tests and docs
- provenance notes in fixture manifests, including Recommendation/example origins where applicable

Do not commit:

- scratch captures
- transient debug output
- machine-specific cache files

## Update Rule

Every new package-owned behavior should ship with either:

1. a released fixture case, or
2. a clear note in docs explaining why the surface is still provisional.
