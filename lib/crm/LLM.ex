defmodule Crm.LLM do
  require Logger

  @default_model "anthropic:claude-haiku-4-5-20251001"

  def draft_email(%{} = lead) do
    model = Application.get_env(:crm, :ai_model, @default_model)
    Logger.info("CRM.LLM: drafting email for lead_id=#{lead.id}")

    context =
      ReqLLM.Context.new([
        ReqLLM.Context.system(Crm.Llm.PromptBuilder.system_prompt()),
        ReqLLM.Context.user(Crm.Llm.PromptBuilder.user_prompt(lead))
      ])

    case ReqLLM.generate_text(model, context, max_tokens: 1024) do
      {:ok, response} ->
        log_usage(response)
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
