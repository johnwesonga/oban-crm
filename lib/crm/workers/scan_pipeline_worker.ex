defmodule Crm.Workers.ScanPipelineWorker do
  use Oban.Worker,
    queue: :pipeline,
    unique: [
      # Only one scan job can be pending/executing at a time
      period: :infinity,
      states: [:available, :executing]
    ]

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("ScanPipelineWorker: scanning for pending leads")

    pending_leads = Crm.Pipeline.list_pending_leads()
    Logger.info("ScanPipelineWorker: found #{length(pending_leads)} pending leads")

    Enum.each(pending_leads, fn lead ->
      Crm.Pipeline.update_lead_status(lead.id, :drafting)

      # Enqueue a draft job for this lead
      %{lead_id: lead.id}
      |> Crm.Workers.DraftEmailWorker.new(
        queue: :drafting,
        unique: [
          # One draft job per lead, keyed on lead_id
          period: :infinity,
          keys: [:lead_id],
          states: [:available, :scheduled, :executing]
        ]
      )
      |> Oban.insert()
    end)

    :ok
  end
end
