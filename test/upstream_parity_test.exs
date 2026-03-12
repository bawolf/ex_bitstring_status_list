defmodule ExBitstringStatusList.UpstreamParityTest do
  use ExUnit.Case, async: true

  @fixtures_root Path.expand("fixtures/upstream/released", __DIR__)

  test "released fixture corpus matches current outputs" do
    manifest = load_json(Path.join(@fixtures_root, "manifest.json"))

    for test_case <- manifest["cases"] do
      recorded = load_json(Path.join([@fixtures_root, "cases", test_case["file"]]))

      assert run_operation(recorded["operation"], recorded["input"]) == recorded["expected"],
             inspect(%{case: test_case["id"], expected: recorded["expected"]}, pretty: true)
    end
  end

  defp run_operation("entry_index", %{"entry" => entry}) do
    case ExBitstringStatusList.entry_index(entry) do
      {:ok, index} -> %{"result" => %{"ok" => index}}
      {:error, reason} -> %{"result" => %{"error" => Atom.to_string(reason)}}
    end
  end

  defp run_operation("status_from_credential", %{"credential" => credential, "entry" => entry}) do
    case ExBitstringStatusList.resolve_status(credential, entry) do
      {:ok, result} ->
        %{
          "status" => result.status,
          "purpose" => result.purpose,
          "valid" => result.valid,
          "message" => result.message
        }

      {:error, reason} ->
        %{"error" => Atom.to_string(reason)}
    end
  end

  defp run_operation("decode", %{"encoded" => encoded, "purpose" => purpose}) do
    case ExBitstringStatusList.decode(encoded, purpose: purpose) do
      {:ok, status_list} ->
        %{
          "size" => status_list.size,
          "statusSize" => status_list.status_size,
          "purpose" => status_list.purpose,
          "statusAt0" => ExBitstringStatusList.raw_status_at(status_list, 0)
        }

      {:error, reason} ->
        %{"error" => Atom.to_string(reason)}
    end
  end

  defp load_json(path) do
    path
    |> File.read!()
    |> Jason.decode!()
  end
end
