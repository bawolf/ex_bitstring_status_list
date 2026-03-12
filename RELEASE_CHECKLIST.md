# Release Checklist

Before publishing `ex_bitstring_status_list`:

1. Run `mix release.gate`.
2. Confirm `README.md`, `SUPPORTED_FEATURES.md`, `INTEROP_NOTES.md`, and `FIXTURE_POLICY.md` still match the shipped behavior.
3. Confirm released fixture manifests still cover the supported package-owned surfaces.
4. Update `CHANGELOG.md`.
5. Sync `libs/ex_bitstring_status_list` into a clean checkout of `github.com/bawolf/ex_bitstring_status_list` with `scripts/sync_standalone_repo.sh /path/to/ex_bitstring_status_list_repo`.
6. Review the standalone repo diff and run `mix release.gate` in the standalone repo before pushing.
7. Trigger the publish workflow from the standalone repo; it should publish to Hex and create the matching tag and GitHub release automatically.
