defmodule ExBitstringStatusList.StatusResult do
  @moduledoc """
  Resolved status information for a status-list entry.
  """

  @enforce_keys [:status, :purpose, :valid, :status_size]
  defstruct [:status, :purpose, :valid, :message, :status_size, :status_reference]

  @type t :: %__MODULE__{
          status: non_neg_integer(),
          purpose: String.t(),
          valid: boolean(),
          message: String.t() | nil,
          status_size: pos_integer(),
          status_reference: String.t() | nil
        }
end
