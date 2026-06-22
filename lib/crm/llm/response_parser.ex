defmodule Crm.Llm.ResponseParser do
  require Logger

  @doc """
  Parses and validates the raw LLM response string into
  a %{subject: ..., body: ...} map.
  """
  def parse(raw_response) when is_binary(raw_response) do
    with {:ok, decoded} <- decode_json(raw_response),
         {:ok, validated} <- validate_fields(decoded) do
      {:ok, validated}
    end
  end

  defp decode_json(raw) do
    # Strip markdown fences if the LLM ignores instructions
    cleaned =
      raw
      |> String.replace(~r/```json\n?/, "")
      |> String.replace(~r/```\n?/, "")
      |> String.trim()

    case Jason.decode(cleaned) do
      {:ok, map} ->
        {:ok, map}

      {:error, reason} ->
        Logger.error("ResponseParser: JSON decode failed: #{inspect(reason)}, raw: #{raw}")
        {:error, :invalid_json}
    end
  end

  defp validate_fields(%{"subject" => subject, "body" => body})
       when is_binary(subject) and is_binary(body) and
              byte_size(subject) > 0 and byte_size(body) > 0 do
    {:ok, %{subject: String.trim(subject), body: String.trim(body)}}
  end

  defp validate_fields(map) do
    Logger.error("ResponseParser: missing or empty fields in: #{inspect(map)}")
    {:error, :missing_fields}
  end
end
