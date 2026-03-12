# ex_bitstring_status_list

[![Hex.pm](https://img.shields.io/hexpm/v/ex_bitstring_status_list.svg)](https://hex.pm/packages/ex_bitstring_status_list)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/ex_bitstring_status_list)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/bawolf/ex_bitstring_status_list/blob/main/LICENSE)

`ex_bitstring_status_list` is a focused Elixir library for Bitstring Status List
credentials and entry verification.

Quick links: [Hex package](https://hex.pm/packages/ex_bitstring_status_list) | [Hex docs](https://hexdocs.pm/ex_bitstring_status_list) | [Supported features](https://github.com/bawolf/ex_bitstring_status_list/blob/main/SUPPORTED_FEATURES.md) | [Interop notes](https://github.com/bawolf/ex_bitstring_status_list/blob/main/INTEROP_NOTES.md) | [Fixture policy](https://github.com/bawolf/ex_bitstring_status_list/blob/main/FIXTURE_POLICY.md)

The package owns status-list-specific semantics:

- allocate stable entry indices
- encode and decode bitstring lists
- construct `BitstringStatusListEntry` values
- construct `BitstringStatusListCredential` credentials
- resolve entry status from a decoded list or full credential

Generic VC envelope validation belongs in `ex_vc`. DID and key resolution belong
in `ex_did`.

## Status

Current support:

- Recommendation-shaped bitstring construction with a 16KB privacy floor
- multibase base64url + GZIP `encodedList` encoding/decoding
- `revocation`, `suspension`, `refresh`, and `message` purposes
- entry generation, validation, and index parsing
- status resolution from a decoded list or a full `BitstringStatusListCredential`
- `statusSize`, `statusMessages`, `statusReference`, and `ttl` support
- contractual released fixture corpus for package-owned behavior and Recommendation examples

Deliberately out of scope:

- generic VC validation
- cryptographic proof verification
- DID resolution
- issuer workflow and protocol transport

## Installation

```elixir
def deps do
  [
    {:ex_bitstring_status_list, "~> 0.1.0"}
  ]
end
```

## Usage

Build a list and allocate an entry:

```elixir
{:ok, status_list, index} =
  ExBitstringStatusList.new_status_list(size: 1024)
  |> ExBitstringStatusList.allocate_index()

entry =
  ExBitstringStatusList.entry("https://issuer.example/status/revocation", index)
```

Revoke an index and resolve its status:

```elixir
status_list =
  ExBitstringStatusList.new_status_list(size: 8)
  |> ExBitstringStatusList.revoke(3)

ExBitstringStatusList.status_at(status_list, 3)
# => :revoked
```

Build a message-oriented status list:

```elixir
status_list =
  ExBitstringStatusList.new_status_list(
    purpose: "message",
    status_size: 2,
    status_messages: [
      %{"status" => "0x0", "message" => "pending_review"},
      %{"status" => "0x1", "message" => "accepted"},
      %{"status" => "0x2", "message" => "rejected"},
      %{"status" => "0x3", "message" => "undefined"}
    ],
    status_reference: "https://example.org/status-dictionary/"
  )
```

Serialize to a status list credential:

```elixir
credential =
  ExBitstringStatusList.to_credential(status_list,
    id: "https://issuer.example/status/revocation",
    issuer: "did:web:issuer.example"
  )
```

Resolve status directly from the credential plus entry:

```elixir
ExBitstringStatusList.status_from_credential(credential, entry)
# => :active | :revoked | integer
```

Resolve the Recommendation-shaped status result:

```elixir
{:ok, result} = ExBitstringStatusList.resolve_status(credential, entry)

result.status
result.valid
result.message
```

## Testing And Fixtures

The library is tested with:

- direct unit tests for Recommendation-shaped package behavior
- golden fixtures for deterministic credential examples
- released fixtures derived from W3C Recommendation examples and package-owned deterministic cases
- a release gate that verifies formatting, compile, tests, docs, and Hex package build

Normal `mix test` and normal library usage do not require Node, Rust, or
network access. The committed released fixtures are the contract for currently
supported package-owned behavior.

Run the local release gate with:

```bash
mix release.gate
```

## Release Automation

The standalone `ex_bitstring_status_list` repository is expected to carry:

- CI on push and pull request
- a manual publish workflow

The publish workflow should be triggered through `workflow_dispatch` after the
version and changelog are ready. It publishes to Hex first and then creates the
matching Git tag and GitHub release automatically. It expects a `HEX_API_KEY`
repository secret in the standalone `ex_bitstring_status_list` repository.

## Maintainer Workflow

`ex_bitstring_status_list` currently lives in the `delegate` monorepo and is
mirrored into the standalone `ex_bitstring_status_list` repository for
publishing and external consumption.

The intended workflow is:

1. make library changes in `libs/ex_bitstring_status_list`
2. run `mix release.gate`
3. sync the package into a clean checkout of `github.com/bawolf/ex_bitstring_status_list`
4. review and push from the standalone repo
5. trigger the publish workflow from the standalone repo

A helper script for the sync step lives at `scripts/sync_standalone_repo.sh`.
