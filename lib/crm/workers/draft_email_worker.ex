defmodule Crm.Workers.DraftEmailWorker do
  use Oban.Worker,
    queue: :drafting,
    max_attempts: 3

  require Logger

  @impl Oban.Worker

  def perform(%Oban.Job{
        args: %{"lead_id" => lead_id},
        attempt: attempt,
        max_attempts: max_attempts
      }) do
    lead = Crm.Pipeline.get_lead!(lead_id)

    Logger.info("DraftEmailWorker: drafting email for lead #{lead_id}")

    case Crm.LLM.draft_email(lead) do
      {:ok, %{subject: subject, body: body}} ->
        Logger.info("DraftEmailWorker: subject: #{subject} body: #{body}")
        {:ok, updated_lead} = Crm.Pipeline.record_drafted(lead, %{subject: subject, body: body})

        Phoenix.PubSub.broadcast(
          Crm.PubSub,
          "email_drafts",
          {:new_draft, updated_lead}
        )

        :ok

      {:error, reason} ->
        Logger.error(
          "DraftEmailWorker: failed to draft email for lead #{lead_id}: #{inspect(reason)}"
        )

        if attempt >= max_attempts, do: Crm.Pipeline.record_error(lead_id, reason)
        {:error, reason}
    end
  end

  @impl Oban.Worker
  def timeout(_job), do: :timer.seconds(30)
end
