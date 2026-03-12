defmodule ExBitstringStatusList.Entry do
  @moduledoc """
  Normalized `BitstringStatusListEntry`.
  """

  @enforce_keys [:status_purpose, :status_list_credential, :status_list_index, :status_size]
  defstruct [
    :id,
    :type,
    :status_purpose,
    :status_list_credential,
    :status_list_index,
    :status_size,
    :status_message,
    :status_reference
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: String.t() | nil,
          status_purpose: String.t(),
          status_list_credential: String.t(),
          status_list_index: non_neg_integer(),
          status_size: pos_integer(),
          status_message: [map()] | nil,
          status_reference: String.t() | nil
        }

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = entry) do
    %{
      "type" => entry.type || "BitstringStatusListEntry",
      "statusPurpose" => entry.status_purpose,
      "statusListCredential" => entry.status_list_credential,
      "statusListIndex" => Integer.to_string(entry.status_list_index)
    }
    |> maybe_put("id", entry.id)
    |> maybe_put("statusSize", if(entry.status_size == 1, do: nil, else: entry.status_size))
    |> maybe_put("statusMessage", entry.status_message)
    |> maybe_put("statusReference", entry.status_reference)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
