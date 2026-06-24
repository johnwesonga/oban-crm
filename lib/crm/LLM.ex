defmodule Crm.LLM do
  require Logger

  @default_model "anthropic:claude-haiku-4-5-20251001"

  def draft_email(%{} = lead) do
    # use local LLM either LM Studio or OMLX
    ai_base_url = Application.get_env(:crm, :ai_base_url, "http://localhost:1234/v1")
    ai_model = Application.get_env(:crm, :ai_model, @default_model)

    local_model =
      ReqLLM.model!(%{
        id: ai_model,
        base_url: ai_base_url,
        provider: "openai",
        max_tokens: 4096,
        receive_timeout: 120_000
      })

    _model = Application.get_env(:crm, :ai_model, @default_model)
    Logger.info("CRM.LLM: drafting email for lead_id=#{lead.id} with ai_model:#{ai_model}")

    context =
      ReqLLM.Context.new([
        ReqLLM.Context.system(Crm.Llm.PromptBuilder.system_prompt()),
        ReqLLM.Context.user(Crm.Llm.PromptBuilder.user_prompt(lead))
      ])

    case ReqLLM.generate_text(local_model, context) do
      {:ok, response} ->
        # log_usage(response)
        Logger.info("CRM.LLM: response=#{inspect(response)}")

        response
        |> ReqLLM.Response.text()
        |> Crm.Llm.ResponseParser.parse()

      {:error, reason} ->
        Logger.error("CRM.LLM: request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp log_usage(response) do
    case ReqLLM.Response.usage(response) do
      nil ->
        :ok

      usage ->
        Logger.debug(
          "[Crm.LLM] tokens in=#{usage.input_tokens} out=#{usage.output_tokens}" <>
            if(usage[:total_cost], do: " cost=$#{usage.total_cost}", else: "")
        )
    end
  end
end
