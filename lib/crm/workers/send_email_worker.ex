defmodule Crm.Workers.SendEmailWorker do
  use Oban.Worker,
    queue: :sending,
    # More retries for sends — SMTP can be flaky
    max_attempts: 5,
    # 0 = highest priority (scale 0–3)
    priority: 0

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"lead_id" => lead_id, "subject" => subject, "body" => body},
        attempt: attempt,
        max_attempts: max_attempts
      }) do
    lead = Crm.Pipeline.get_lead!(lead_id)

    Logger.info("SendEmailWorker: sending to #{lead.email_address}")

    case Crm.Mailer.send_email(lead.email_address, subject, body) do
      {:ok, _} ->
        Crm.Pipeline.update_lead_status(lead.id, :sent)
        :ok

      {:error, %{status: 429}} ->
        # Rate limited — snooze and retry later
        Logger.warning("SendEmailWorker: rate limited, snoozing 60s")
        {:snooze, 60}

      {:error, reason} ->
        Logger.error("SendEmailWorker: delivery failed for lead #{lead_id}: #{inspect(reason)}")
        if attempt >= max_attempts, do: Crm.Pipeline.record_error(lead_id, reason)
        {:error, reason}
    end
  end
end
