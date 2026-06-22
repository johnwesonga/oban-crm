defmodule Crm.Pipeline do
  import Ecto.Query
  alias Crm.Repo
  alias Crm.Pipeline.Lead

  def list_leads do
    from(l in Lead, order_by: [desc: l.inserted_at])
    |> Repo.all()
  end

  def list_pending_leads do
    from(l in Lead, where: l.already_emailed == :pending)
    |> Repo.all()
  end

  def list_awaiting_review_leads do
    from(l in Lead, where: l.already_emailed == :awaiting_review, order_by: [asc: l.drafted_at])
    |> Repo.all()
  end

  def get_lead!(id), do: Repo.get!(Lead, id)

  def create_lead(attrs) do
    %Lead{}
    |> Lead.changeset(attrs)
    |> Repo.insert()
  end

  def update_lead_status(lead_id, status) do
    lead = get_lead!(lead_id)

    with {:ok, updated_lead} <- lead |> Lead.status_changeset(status) |> Repo.update() do
      broadcast_lead_updated(updated_lead)
      {:ok, updated_lead}
    end
  end

  def record_drafted(lead, %{subject: _, body: _} = draft) do
    with {:ok, updated_lead} <- lead |> Lead.drafted_changeset(draft) |> Repo.update() do
      broadcast_lead_updated(updated_lead)
      {:ok, updated_lead}
    end
  end

  def approve_lead(lead) do
    with {:ok, updated_lead} <- lead |> Lead.status_changeset(:approved) |> Repo.update() do
      broadcast_lead_updated(updated_lead)

      %{
        "lead_id" => updated_lead.id,
        "subject" => updated_lead.draft_subject,
        "body" => updated_lead.draft_body
      }
      |> Crm.Workers.SendEmailWorker.new()
      |> Oban.insert()

      {:ok, updated_lead}
    end
  end

  def record_sent(lead_id) do
    with {:ok, updated_lead} <-
           get_lead!(lead_id) |> Lead.sent_changeset() |> Repo.update() do
      broadcast_lead_updated(updated_lead)
      {:ok, updated_lead}
    end
  end

  def record_error(lead_id, reason) do
    with {:ok, updated_lead} <-
           get_lead!(lead_id) |> Lead.error_changeset(reason) |> Repo.update() do
      broadcast_lead_updated(updated_lead)
      {:ok, updated_lead}
    end
  end

  defp broadcast_lead_updated(lead) do
    Phoenix.PubSub.broadcast(Crm.PubSub, "leads", {:lead_updated, lead})
  end

  def update_lead(lead, attrs) do
    lead
    |> Lead.changeset(attrs)
    |> Repo.update()
  end

  def delete_lead(lead) do
    Repo.delete(lead)
  end

  def change_lead(lead, attrs \\ %{}) do
    Lead.changeset(lead, attrs)
  end
end
