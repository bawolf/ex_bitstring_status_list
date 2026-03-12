defmodule ExBitstringStatusList do
  @moduledoc """
  Bitstring Status List support for verifiable credentials.

  This package owns status-list entry construction, status-list credential
  construction, and status resolution from either a decoded status list or a
  full `BitstringStatusListCredential`. Generic VC envelope validation belongs
  in `ex_vc`.
  """

  alias ExBitstringStatusList.Entry
  alias ExBitstringStatusList.StatusResult

  @status_context "https://www.w3.org/ns/credentials/v2"
  @multibase_prefix "u"
  @minimum_bit_length 131_072
  @supported_status_purposes ~w(refresh revocation suspension message)

  @typedoc "Stable error atoms returned by the public API."
  @type reason ::
          :invalid_encoding
          | :invalid_multibase
          | :invalid_status_list
          | :invalid_status_list_credential
          | :invalid_status_list_entry
          | :invalid_status_list_index
          | :invalid_status_messages
          | :invalid_status_purpose
          | :invalid_status_reference
          | :invalid_status_size
          | :invalid_status_value
          | :invalid_ttl
          | :missing_encoded_list
          | :missing_status_list_index
          | :missing_status_list_credential
          | :missing_status_messages
          | :missing_status_purpose
          | :out_of_range
          | :status_list_full

  @typedoc "Keyword options accepted when constructing a status list."
  @type option ::
          {:size, pos_integer()}
          | {:purpose, String.t()}
          | {:revoked, [non_neg_integer()]}
          | {:next_index, non_neg_integer()}
          | {:status_size, pos_integer()}
          | {:statuses, %{optional(non_neg_integer()) => non_neg_integer()}}
          | {:status_messages, [map()]}
          | {:status_reference, String.t()}
          | {:ttl, non_neg_integer()}

  @enforce_keys [:purpose, :size, :status_size, :statuses, :next_index]
  defstruct [
    :purpose,
    :size,
    :status_size,
    :status_messages,
    :status_reference,
    :ttl,
    :statuses,
    :next_index,
    revoked: MapSet.new()
  ]

  @typedoc """
  In-memory Bitstring Status List state.

  `size` is the number of credential entries in the list, not the number of
  bits. The underlying uncompressed bitstring is `size * status_size` bits and
  is always at least 16KB, per the Recommendation.
  """
  @type t :: %__MODULE__{
          purpose: String.t(),
          size: pos_integer(),
          status_size: pos_integer(),
          status_messages: [map()] | nil,
          status_reference: String.t() | nil,
          ttl: non_neg_integer() | nil,
          statuses: %{optional(non_neg_integer()) => non_neg_integer()},
          next_index: non_neg_integer(),
          revoked: MapSet.t(non_neg_integer())
        }

  @doc """
  Builds a new status list, returning a tagged tuple.
  """
  @spec new(keyword(option())) :: {:ok, t()} | {:error, reason()}
  def new(opts \\ []) do
    purpose = Keyword.get(opts, :purpose, "revocation")
    status_size = Keyword.get(opts, :status_size, 1)
    requested_size = Keyword.get(opts, :size, minimum_entry_count(status_size))
    size = max(requested_size, minimum_entry_count(status_size))
    next_index = Keyword.get(opts, :next_index, 0)
    ttl = Keyword.get(opts, :ttl)
    status_reference = Keyword.get(opts, :status_reference)

    with :ok <- validate_status_purpose(purpose),
         :ok <- validate_status_size(status_size),
         :ok <- validate_ttl(ttl),
         :ok <- validate_status_reference(status_reference),
         {:ok, status_messages} <-
           normalize_status_messages(Keyword.get(opts, :status_messages), status_size),
         {:ok, statuses} <-
           normalize_statuses(
             Keyword.get(opts, :statuses, %{}),
             Keyword.get(opts, :revoked, []),
             size,
             status_size
           ),
         :ok <- validate_next_index(next_index, size) do
      {:ok,
       %__MODULE__{
         purpose: purpose,
         size: size,
         status_size: status_size,
         status_messages: status_messages,
         status_reference: status_reference,
         ttl: ttl,
         statuses: statuses,
         next_index: next_index,
         revoked: revoked_set(statuses, status_size)
       }}
    end
  end

  @doc """
  Convenience constructor that raises on invalid options.
  """
  @spec new_status_list(keyword(option())) :: t()
  def new_status_list(opts \\ []) do
    case new(opts) do
      {:ok, status_list} ->
        status_list

      {:error, reason} ->
        raise ArgumentError, "invalid status list options: #{inspect(reason)}"
    end
  end

  @doc """
  Allocates the next available index in the status list.
  """
  @spec allocate_index(t()) :: {:ok, t(), non_neg_integer()} | {:error, :status_list_full}
  def allocate_index(%__MODULE__{next_index: next_index, size: size}) when next_index >= size do
    {:error, :status_list_full}
  end

  def allocate_index(%__MODULE__{} = status_list) do
    {:ok, %{status_list | next_index: status_list.next_index + 1}, status_list.next_index}
  end

  @doc """
  Sets a status value for the given index.
  """
  @spec put_status(t(), non_neg_integer(), non_neg_integer()) :: {:ok, t()} | {:error, reason()}
  def put_status(%__MODULE__{} = status_list, index, value)
      when is_integer(index) and index >= 0 and is_integer(value) and value >= 0 do
    with :ok <- validate_index(index, status_list.size),
         :ok <- validate_status_value(value, status_list.status_size) do
      statuses =
        case value do
          0 -> Map.delete(status_list.statuses, index)
          _ -> Map.put(status_list.statuses, index, value)
        end

      {:ok,
       %{
         status_list
         | statuses: statuses,
           revoked: revoked_set(statuses, status_list.status_size)
       }}
    end
  end

  def put_status(%__MODULE__{}, _index, _value), do: {:error, :invalid_status_value}

  @doc """
  Convenience helper that marks an entry as non-zero.

  For single-bit revocation/suspension lists this marks the entry as revoked.
  """
  @spec revoke(t(), non_neg_integer()) :: t()
  def revoke(%__MODULE__{} = status_list, index) do
    case put_status(status_list, index, 1) do
      {:ok, updated} -> updated
      {:error, reason} -> raise ArgumentError, "cannot revoke index #{index}: #{inspect(reason)}"
    end
  end

  @doc """
  Returns the raw status value for an index, or `:out_of_range`.
  """
  @spec raw_status_at(t(), non_neg_integer()) :: non_neg_integer() | :out_of_range
  def raw_status_at(%__MODULE__{size: size}, index)
      when not is_integer(index) or index < 0 or index >= size,
      do: :out_of_range

  def raw_status_at(%__MODULE__{} = status_list, index),
    do: Map.get(status_list.statuses, index, 0)

  @doc """
  Compatibility helper for reading the status of an index.

  Returns `:active` / `:revoked` for single-bit lists and the raw integer status
  value for multi-bit lists.
  """
  @spec status_at(t(), non_neg_integer()) ::
          :active | :revoked | non_neg_integer() | :out_of_range
  def status_at(%__MODULE__{status_size: 1} = status_list, index) do
    case raw_status_at(status_list, index) do
      :out_of_range -> :out_of_range
      0 -> :active
      _ -> :revoked
    end
  end

  def status_at(%__MODULE__{} = status_list, index), do: raw_status_at(status_list, index)

  @doc """
  Builds a `BitstringStatusListEntry`.
  """
  @spec build_entry(String.t(), non_neg_integer(), keyword()) ::
          {:ok, Entry.t()} | {:error, reason()}
  def build_entry(status_list_credential, index, opts \\ []) do
    entry =
      %{
        "id" => status_list_credential <> "#" <> Integer.to_string(index),
        "type" => "BitstringStatusListEntry",
        "statusPurpose" => Keyword.get(opts, :purpose, "revocation"),
        "statusListCredential" => status_list_credential,
        "statusListIndex" => Integer.to_string(index)
      }
      |> maybe_put("statusSize", Keyword.get(opts, :status_size))
      |> maybe_put("statusMessage", Keyword.get(opts, :status_message))
      |> maybe_put("statusReference", Keyword.get(opts, :status_reference))

    validate_entry(entry)
  end

  @doc """
  Compatibility helper that returns a plain map entry.
  """
  @spec entry(String.t(), non_neg_integer(), keyword()) :: map()
  def entry(status_list_credential, index, opts \\ []) do
    case build_entry(status_list_credential, index, opts) do
      {:ok, %Entry{} = entry} -> Entry.to_map(entry)
      {:error, reason} -> raise ArgumentError, "invalid status list entry: #{inspect(reason)}"
    end
  end

  @doc """
  Validates and normalizes a status list entry.
  """
  @spec validate_entry(map()) :: {:ok, Entry.t()} | {:error, reason()}
  def validate_entry(entry) when is_map(entry) do
    with {:ok, index} <- entry_index(entry),
         {:ok, status_list_credential} <-
           fetch_binary(entry, "statusListCredential", :missing_status_list_credential),
         {:ok, purpose} <- fetch_status_purpose(entry, "statusPurpose"),
         {:ok, status_size} <- fetch_status_size(entry, "statusSize", 1),
         {:ok, status_message} <-
           normalize_entry_status_message(Map.get(entry, "statusMessage"), status_size),
         :ok <- validate_status_reference(Map.get(entry, "statusReference")) do
      {:ok,
       %Entry{
         id: Map.get(entry, "id"),
         type: Map.get(entry, "type", "BitstringStatusListEntry"),
         status_purpose: purpose,
         status_list_credential: status_list_credential,
         status_list_index: index,
         status_size: status_size,
         status_message: status_message,
         status_reference: Map.get(entry, "statusReference")
       }}
    end
  end

  def validate_entry(_entry), do: {:error, :invalid_status_list_entry}

  @doc """
  Parses the `statusListIndex` from an entry.
  """
  @spec entry_index(map()) :: {:ok, non_neg_integer()} | {:error, reason()}
  def entry_index(%{"statusListIndex" => index}) when is_binary(index) do
    case Integer.parse(index) do
      {value, ""} when value >= 0 -> {:ok, value}
      _ -> {:error, :invalid_status_list_index}
    end
  end

  def entry_index(_entry), do: {:error, :missing_status_list_index}

  @doc """
  Encodes the status list according to the Recommendation.
  """
  @spec encode(t()) :: String.t()
  def encode(%__MODULE__{} = status_list) do
    status_list
    |> to_bitstring()
    |> :zlib.gzip()
    |> Base.url_encode64(padding: false)
    |> then(&(@multibase_prefix <> &1))
  end

  @doc """
  Decodes a compressed status list into in-memory state.
  """
  @spec decode(String.t(), keyword()) :: {:ok, t()} | {:error, reason()}
  def decode(encoded, opts \\ [])

  def decode(encoded, opts) when is_binary(encoded) do
    with {:ok, bitstring} <- decode_to_bitstring(encoded),
         {:ok, purpose} <- decode_purpose(opts),
         {:ok, status_size} <- decode_status_size(opts),
         {:ok, status_messages} <-
           normalize_status_messages(Keyword.get(opts, :status_messages), status_size),
         :ok <- validate_status_reference(Keyword.get(opts, :status_reference)),
         :ok <- validate_ttl(Keyword.get(opts, :ttl)),
         :ok <- validate_bit_length(bit_size(bitstring), status_size),
         {:ok, statuses, entry_count} <- parse_bitstring(bitstring, status_size) do
      {:ok,
       %__MODULE__{
         purpose: purpose,
         size: entry_count,
         status_size: status_size,
         status_messages: status_messages,
         status_reference: Keyword.get(opts, :status_reference),
         ttl: Keyword.get(opts, :ttl),
         statuses: statuses,
         next_index: Keyword.get(opts, :next_index, entry_count),
         revoked: revoked_set(statuses, status_size)
       }}
    end
  end

  def decode(_encoded, _opts), do: {:error, :invalid_encoding}

  @doc """
  Builds a `BitstringStatusListCredential`.
  """
  @spec build_credential(t(), keyword()) :: {:ok, map()} | {:error, reason()}
  def build_credential(%__MODULE__{} = status_list, opts) do
    with {:ok, id} <- fetch_option(opts, :id),
         {:ok, issuer} <- fetch_option(opts, :issuer) do
      valid_from =
        Keyword.get(opts, :valid_from, DateTime.utc_now() |> DateTime.truncate(:second))

      subject =
        %{
          "id" => id <> "#list",
          "type" => "BitstringStatusList",
          "statusPurpose" => status_list.purpose,
          "encodedList" => encode(status_list)
        }
        |> maybe_put("statusSize", status_size_for_subject(status_list))
        |> maybe_put("statusMessages", status_messages_for_subject(status_list))
        |> maybe_put("statusReference", status_list.status_reference)
        |> maybe_put("ttl", status_list.ttl)

      {:ok,
       %{
         "@context" => [@status_context],
         "id" => id,
         "type" => ["VerifiableCredential", "BitstringStatusListCredential"],
         "issuer" => issuer,
         "validFrom" => DateTime.to_iso8601(valid_from),
         "credentialSubject" => subject
       }}
    end
  end

  @doc """
  Compatibility helper that returns a plain credential map.
  """
  @spec to_credential(t(), keyword()) :: map()
  def to_credential(%__MODULE__{} = status_list, opts) do
    case build_credential(status_list, opts) do
      {:ok, credential} ->
        credential

      {:error, reason} ->
        raise ArgumentError, "invalid status list credential options: #{inspect(reason)}"
    end
  end

  @doc """
  Validates and decodes a `BitstringStatusListCredential`.
  """
  @spec from_credential(map()) :: {:ok, t()} | {:error, reason()}
  def from_credential(%{
        "type" => types,
        "credentialSubject" => credential_subject
      })
      when is_list(types) and is_map(credential_subject) do
    with true <- "BitstringStatusListCredential" in types,
         "BitstringStatusList" <- Map.get(credential_subject, "type"),
         {:ok, purpose} <- decode_status_purpose(credential_subject),
         {:ok, encoded} <- fetch_binary(credential_subject, "encodedList", :missing_encoded_list),
         {:ok, status_size} <- fetch_status_size(credential_subject, "statusSize", 1),
         {:ok, status_messages} <-
           normalize_subject_status_messages(
             Map.get(credential_subject, "statusMessages"),
             status_size,
             purpose
           ),
         :ok <- validate_status_reference(Map.get(credential_subject, "statusReference")),
         :ok <- validate_ttl(Map.get(credential_subject, "ttl")),
         {:ok, status_list} <-
           decode(encoded,
             purpose: purpose,
             status_size: status_size,
             status_messages: status_messages,
             status_reference: Map.get(credential_subject, "statusReference"),
             ttl: Map.get(credential_subject, "ttl")
           ) do
      {:ok, status_list}
    else
      false -> {:error, :invalid_status_list_credential}
      _ -> {:error, :invalid_status_list_credential}
    end
  end

  def from_credential(_credential), do: {:error, :invalid_status_list_credential}

  @doc """
  Resolves the status for an entry from a decoded status list or a full credential.
  """
  @spec resolve_status(t() | map(), map()) :: {:ok, StatusResult.t()} | {:error, reason()}
  def resolve_status(%__MODULE__{} = status_list, entry) do
    with {:ok, %Entry{} = entry} <- validate_entry(entry),
         :ok <- validate_purpose_match(status_list.purpose, entry.status_purpose),
         :ok <- validate_status_size_match(status_list.status_size, entry.status_size),
         :ok <- validate_index(entry.status_list_index, status_list.size),
         value when is_integer(value) <- raw_status_at(status_list, entry.status_list_index) do
      {:ok, build_status_result(status_list, entry, value)}
    end
  end

  def resolve_status(credential, entry) when is_map(credential) and is_map(entry) do
    with {:ok, status_list} <- from_credential(credential) do
      resolve_status(status_list, entry)
    end
  end

  @doc """
  Compatibility helper that returns the simplified status from a decoded list.
  """
  @spec status_from_entry(t(), map()) ::
          :active | :revoked | non_neg_integer() | :out_of_range | :invalid
  def status_from_entry(%__MODULE__{} = status_list, entry) do
    case resolve_status(status_list, entry) do
      {:ok, %StatusResult{status: 0, status_size: 1}} -> :active
      {:ok, %StatusResult{status_size: 1}} -> :revoked
      {:ok, %StatusResult{status: status}} -> status
      {:error, :out_of_range} -> :out_of_range
      {:error, _reason} -> :invalid
    end
  end

  @doc """
  Compatibility helper that returns the simplified status from a full credential.
  """
  @spec status_from_credential(map(), map()) ::
          :active | :revoked | non_neg_integer() | :out_of_range | :invalid
  def status_from_credential(credential, entry) when is_map(credential) and is_map(entry) do
    case resolve_status(credential, entry) do
      {:ok, %StatusResult{status: 0, status_size: 1}} -> :active
      {:ok, %StatusResult{status_size: 1}} -> :revoked
      {:ok, %StatusResult{status: status}} -> status
      {:error, :out_of_range} -> :out_of_range
      {:error, _reason} -> :invalid
    end
  end

  def status_from_credential(_credential, _entry), do: :invalid

  defp build_status_result(status_list, entry, value) do
    message =
      case {status_list.purpose, status_list.status_messages} do
        {"message", messages} when is_list(messages) -> message_for_status(messages, value)
        _ -> nil
      end

    %StatusResult{
      status: value,
      purpose: status_list.purpose,
      valid: value == 0,
      message: message,
      status_size: entry.status_size,
      status_reference: entry.status_reference || status_list.status_reference
    }
  end

  defp normalize_statuses(statuses, revoked, size, status_size) when is_map(statuses) do
    revoked_statuses =
      revoked
      |> List.wrap()
      |> Enum.reduce(%{}, fn index, acc -> Map.put(acc, index, 1) end)

    statuses = Map.merge(revoked_statuses, statuses)

    Enum.reduce_while(statuses, {:ok, %{}}, fn {index, value}, {:ok, acc} ->
      with :ok <- validate_index(index, size),
           :ok <- validate_status_value(value, status_size) do
        next =
          case value do
            0 -> Map.delete(acc, index)
            _ -> Map.put(acc, index, value)
          end

        {:cont, {:ok, next}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp normalize_statuses(_statuses, _revoked, _size, _status_size),
    do: {:error, :invalid_status_list}

  defp normalize_status_messages(nil, 1), do: {:ok, nil}

  defp normalize_status_messages(nil, status_size) when status_size > 1,
    do: {:error, :missing_status_messages}

  defp normalize_status_messages(status_messages, status_size) when is_list(status_messages) do
    expected_size = status_message_count(status_size)

    with true <- length(status_messages) == expected_size,
         {:ok, normalized} <- normalize_status_message_entries(status_messages, expected_size) do
      {:ok, normalized}
    else
      false -> {:error, :invalid_status_messages}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_status_messages(_, _status_size), do: {:error, :invalid_status_messages}

  defp normalize_status_message_entries(status_messages, expected_size) do
    Enum.with_index(status_messages)
    |> Enum.reduce_while({:ok, []}, fn {entry, index}, {:ok, acc} ->
      with %{"status" => status, "message" => message}
           when is_binary(status) and is_binary(message) <- entry,
           true <- String.downcase(status) == expected_status_hex(index) do
        {:cont, {:ok, acc ++ [entry]}}
      else
        _ -> {:halt, {:error, :invalid_status_messages}}
      end
    end)
    |> case do
      {:ok, normalized} when length(normalized) == expected_size -> {:ok, normalized}
      {:ok, _} -> {:error, :invalid_status_messages}
      error -> error
    end
  end

  defp normalize_entry_status_message(nil, _status_size), do: {:ok, nil}

  defp normalize_entry_status_message(status_message, status_size) when is_list(status_message) do
    normalize_status_messages(status_message, status_size)
  end

  defp normalize_entry_status_message(_status_message, _status_size),
    do: {:error, :invalid_status_messages}

  defp normalize_subject_status_messages(nil, _status_size, "message"),
    do: {:error, :missing_status_messages}

  defp normalize_subject_status_messages(status_messages, status_size, "message"),
    do: normalize_status_messages(status_messages, status_size)

  defp normalize_subject_status_messages(status_messages, status_size, _purpose) do
    case status_messages do
      nil -> normalize_status_messages(nil, status_size)
      list when is_list(list) -> normalize_status_messages(list, status_size)
      _ -> {:error, :invalid_status_messages}
    end
  end

  defp validate_status_purpose(purpose) when purpose in @supported_status_purposes, do: :ok
  defp validate_status_purpose(_purpose), do: {:error, :invalid_status_purpose}

  defp validate_status_size(status_size) when is_integer(status_size) and status_size > 0, do: :ok
  defp validate_status_size(_status_size), do: {:error, :invalid_status_size}

  defp validate_status_reference(nil), do: :ok
  defp validate_status_reference(reference) when is_binary(reference), do: :ok
  defp validate_status_reference(_reference), do: {:error, :invalid_status_reference}

  defp validate_ttl(nil), do: :ok
  defp validate_ttl(ttl) when is_integer(ttl) and ttl >= 0, do: :ok
  defp validate_ttl(_ttl), do: {:error, :invalid_ttl}

  defp validate_index(index, size) when is_integer(index) and index >= 0 and index < size, do: :ok
  defp validate_index(_index, _size), do: {:error, :out_of_range}

  defp validate_next_index(next_index, size)
       when is_integer(next_index) and next_index >= 0 and next_index <= size,
       do: :ok

  defp validate_next_index(_next_index, _size), do: {:error, :status_list_full}

  defp validate_status_value(value, status_size) do
    max_value = status_message_count(status_size) - 1

    if is_integer(value) and value >= 0 and value <= max_value do
      :ok
    else
      {:error, :invalid_status_value}
    end
  end

  defp validate_bit_length(bit_length, status_size)
       when bit_length >= @minimum_bit_length and rem(bit_length, status_size) == 0,
       do: :ok

  defp validate_bit_length(_bit_length, _status_size), do: {:error, :invalid_encoding}

  defp validate_purpose_match(left, right) when left == right, do: :ok
  defp validate_purpose_match(_left, _right), do: {:error, :invalid_status_purpose}

  defp validate_status_size_match(left, right) when left == right, do: :ok
  defp validate_status_size_match(_left, _right), do: {:error, :invalid_status_size}

  defp fetch_option(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when is_binary(value) -> {:ok, value}
      _ -> {:error, :invalid_status_list_credential}
    end
  end

  defp fetch_binary(map, key, missing_reason) do
    case Map.fetch(map, key) do
      {:ok, value} when is_binary(value) -> {:ok, value}
      :error -> {:error, missing_reason}
      _ -> {:error, :invalid_status_list_credential}
    end
  end

  defp fetch_status_purpose(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} when is_binary(value) ->
        case validate_status_purpose(value) do
          :ok -> {:ok, value}
          error -> error
        end

      _ ->
        {:error, :missing_status_purpose}
    end
  end

  defp fetch_status_size(map, key, default) do
    case Map.get(map, key, default) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      nil -> {:ok, default}
      _ -> {:error, :invalid_status_size}
    end
  end

  defp decode_purpose(opts) do
    purpose = Keyword.get(opts, :purpose, "revocation")

    case validate_status_purpose(purpose) do
      :ok -> {:ok, purpose}
      error -> error
    end
  end

  defp decode_status_size(opts) do
    status_size = Keyword.get(opts, :status_size, 1)

    case validate_status_size(status_size) do
      :ok -> {:ok, status_size}
      error -> error
    end
  end

  defp decode_status_purpose(credential_subject) do
    case Map.get(credential_subject, "statusPurpose") do
      value when is_binary(value) ->
        case validate_status_purpose(value) do
          :ok -> {:ok, value}
          error -> error
        end

      [value] when is_binary(value) ->
        case validate_status_purpose(value) do
          :ok -> {:ok, value}
          error -> error
        end

      _ ->
        {:error, :missing_status_purpose}
    end
  end

  defp decode_to_bitstring(@multibase_prefix <> encoded) do
    with {:ok, compressed} <- Base.url_decode64(encoded, padding: false),
         {:ok, bitstring} <- gunzip_bitstring(compressed) do
      {:ok, bitstring}
    else
      :error -> {:error, :invalid_encoding}
      {:error, _} = error -> error
    end
  end

  defp decode_to_bitstring(_encoded), do: {:error, :invalid_multibase}

  defp gunzip_bitstring(compressed) do
    try do
      {:ok, :zlib.gunzip(compressed)}
    rescue
      _ -> {:error, :invalid_encoding}
    end
  end

  defp parse_bitstring(bitstring, status_size) do
    entry_count = div(bit_size(bitstring), status_size)

    statuses =
      bitstring
      |> collect_statuses(status_size)
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn
        {0, _index}, acc -> acc
        {value, index}, acc -> Map.put(acc, index, value)
      end)

    {:ok, statuses, entry_count}
  end

  defp collect_statuses(bitstring, status_size) do
    do_collect_statuses(bitstring, status_size, [])
    |> Enum.reverse()
  end

  defp do_collect_statuses(<<>>, _status_size, acc), do: acc

  defp do_collect_statuses(bitstring, status_size, acc) do
    <<value::unsigned-size(status_size), rest::bitstring>> = bitstring
    do_collect_statuses(rest, status_size, [value | acc])
  end

  defp to_bitstring(%__MODULE__{} = status_list) do
    Enum.reduce(0..(status_list.size - 1), <<>>, fn index, acc ->
      value = Map.get(status_list.statuses, index, 0)
      <<acc::bitstring, value::unsigned-size(status_list.status_size)>>
    end)
  end

  defp status_size_for_subject(%__MODULE__{status_size: 1}), do: nil
  defp status_size_for_subject(%__MODULE__{status_size: status_size}), do: status_size

  defp status_messages_for_subject(%__MODULE__{purpose: "message", status_messages: messages}),
    do: messages

  defp status_messages_for_subject(%__MODULE__{status_size: 1, status_messages: nil}), do: nil
  defp status_messages_for_subject(%__MODULE__{status_messages: messages}), do: messages

  defp message_for_status(status_messages, status) do
    status_messages
    |> Enum.find_value(fn entry ->
      if entry["status"] == expected_status_hex(status), do: entry["message"], else: nil
    end)
  end

  defp expected_status_hex(value), do: "0x" <> Integer.to_string(value, 16)

  defp minimum_entry_count(status_size),
    do: div(@minimum_bit_length + status_size - 1, status_size)

  defp status_message_count(status_size), do: Integer.pow(2, status_size)

  defp revoked_set(statuses, 1) do
    statuses
    |> Enum.reduce(MapSet.new(), fn {index, value}, acc ->
      if value > 0, do: MapSet.put(acc, index), else: acc
    end)
  end

  defp revoked_set(_statuses, _status_size), do: MapSet.new()

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
