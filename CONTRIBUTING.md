# Contributing

Thanks for helping improve `ex_bitstring_status_list`.

## Development Model

`ex_bitstring_status_list` is developed in the private `delegate` monorepo and
mirrored into the public `github.com/bawolf/ex_bitstring_status_list`
repository for issues, discussions, releases, and Hex publishing.

- file issues and discussion topics in the public repo
- maintainers land code changes in the monorepo first
- direct standalone-repo edits are temporary hotfixes only and must be
  backported to the monorepo immediately
- community pull requests are welcome, but accepted changes are merged into the
  monorepo and then mirrored back into the public repo

## Good Reports

Please include:

- the `ex_bitstring_status_list` version
- Elixir and OTP versions
- the status-list entry or credential involved
- whether the behavior differs from the spec examples or a consuming VC stack
- a minimal reproduction or fixture when possible

## Release And Mirror Notes

Maintainers use:

- `scripts/release_preflight.sh`
- `scripts/sync_standalone_repo.sh`
- `scripts/verify_standalone_repo.sh`

The monorepo copy is the authoritative source for code, tests, docs, workflows,
and release tooling.
