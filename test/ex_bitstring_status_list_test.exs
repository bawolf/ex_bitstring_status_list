defmodule ExBitstringStatusListTest do
  use ExUnit.Case, async: true

  alias ExBitstringStatusList.StatusResult

  @fixtures_dir Path.expand("fixtures", __DIR__)
  @spec_example_encoded_list "uH4sIAAAAAAAAA-3BMQEAAADCoPVPbQwfoAAAAAAAAAAAAAAAAAAAAIC3AYbSVKsAQAAA"

  test "allocates stable unique indices with the minimum privacy floor" do
    status_list = ExBitstringStatusList.new_status_list(size: 4)

    assert status_list.size == 131_072
    assert {:ok, status_list, 0} = ExBitstringStatusList.allocate_index(status_list)
    assert {:ok, status_list, 1} = ExBitstringStatusList.allocate_index(status_list)
    assert {:ok, _status_list, 2} = ExBitstringStatusList.allocate_index(status_list)
  end

  test "revokes and resolves status correctly for single-bit lists" do
    status_list =
      ExBitstringStatusList.new_status_list(size: 8)
      |> ExBitstringStatusList.revoke(3)

    assert ExBitstringStatusList.status_at(status_list, 3) == :revoked
    assert ExBitstringStatusList.status_at(status_list, 4) == :active
  end

  test "round-trips spec-correct encoding and decoding" do
    status_list =
      ExBitstringStatusList.new_status_list(size: 8)
      |> ExBitstringStatusList.revoke(1)
      |> ExBitstringStatusList.revoke(6)

    encoded = ExBitstringStatusList.encode(status_list)

    assert String.starts_with?(encoded, "u")
    assert {:ok, decoded} = ExBitstringStatusList.decode(encoded, purpose: "revocation")
    assert decoded.size >= 131_072
    assert ExBitstringStatusList.status_at(decoded, 1) == :revoked
    assert ExBitstringStatusList.status_at(decoded, 6) == :revoked
    assert ExBitstringStatusList.status_at(decoded, 0) == :active
  end

  test "resolves status from a decoded list with a spec-shaped result" do
    status_list =
      ExBitstringStatusList.new_status_list(size: 8)
      |> ExBitstringStatusList.revoke(2)

    entry =
      ExBitstringStatusList.entry("https://delegate.local/status-lists/revocation", 2,
        purpose: "revocation"
      )

    assert {:ok, %StatusResult{status: 1, valid: false, purpose: "revocation"}} =
             ExBitstringStatusList.resolve_status(status_list, entry)

    assert ExBitstringStatusList.status_from_entry(status_list, entry) == :revoked
  end

  test "resolves status directly from a status list credential" do
    credential = golden_fixture!("status_list_credential.json")

    entry =
      ExBitstringStatusList.entry("https://example.com/credentials/status/3", 2,
        purpose: "revocation"
      )

    assert {:ok, %StatusResult{status: 0, valid: true, purpose: "revocation"}} =
             ExBitstringStatusList.resolve_status(credential, entry)

    assert ExBitstringStatusList.status_from_credential(credential, entry) == :active
  end

  test "serializes and restores a status list credential" do
    status_list =
      ExBitstringStatusList.new_status_list(size: 8)
      |> ExBitstringStatusList.revoke(5)

    credential =
      ExBitstringStatusList.to_credential(status_list,
        id: "https://delegate.local/status-lists/revocation",
        issuer: "did:web:greenfield.gov"
      )

    assert {:ok, restored} = ExBitstringStatusList.from_credential(credential)
    assert ExBitstringStatusList.status_at(restored, 5) == :revoked
  end

  test "supports message-purpose status lists" do
    status_list =
      ExBitstringStatusList.new_status_list(
        purpose: "message",
        status_size: 2,
        size: 4,
        statuses: %{1 => 2},
        status_messages: [
          %{"status" => "0x0", "message" => "pending_review"},
          %{"status" => "0x1", "message" => "accepted"},
          %{"status" => "0x2", "message" => "rejected"},
          %{"status" => "0x3", "message" => "undefined"}
        ],
        status_reference: "https://example.org/status-dictionary/",
        ttl: 300_000
      )

    credential =
      ExBitstringStatusList.to_credential(status_list,
        id: "https://example.com/credentials/status/8",
        issuer: "did:example:12345"
      )

    entry =
      ExBitstringStatusList.entry("https://example.com/credentials/status/8", 1,
        purpose: "message",
        status_size: 2,
        status_message: credential["credentialSubject"]["statusMessages"],
        status_reference: "https://example.org/status-dictionary/"
      )

    assert {:ok,
            %StatusResult{
              status: 2,
              valid: false,
              purpose: "message",
              message: "rejected",
              status_reference: "https://example.org/status-dictionary/"
            }} = ExBitstringStatusList.resolve_status(credential, entry)

    assert ExBitstringStatusList.status_from_credential(credential, entry) == 2
  end

  test "uses the recommendation example encoded list" do
    assert golden_fixture!("status_list_credential.json")
           |> get_in(["credentialSubject", "encodedList"]) == @spec_example_encoded_list
  end

  test "rejects malformed status list credentials" do
    assert {:error, :invalid_status_list_credential} =
             ExBitstringStatusList.from_credential(%{
               "type" => ["VerifiableCredential"],
               "credentialSubject" => %{
                 "type" => "BitstringStatusList",
                 "encodedList" => "MDAxMDAwMDE",
                 "statusPurpose" => "revocation"
               }
             })
  end

  defp golden_fixture!(name) do
    [@fixtures_dir, "golden", name]
    |> Path.join()
    |> File.read!()
    |> Jason.decode!()
  end
end
