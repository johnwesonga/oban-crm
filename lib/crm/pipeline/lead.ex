defmodule Crm.Pipeline.Lead do
  use Ecto.Schema
  import Ecto.Changeset

  @already_emailed_values [:pending, :drafting, :awaiting_review, :approved, :sent, :failed]

  schema "sales_pipeline" do
    field :email_address, :string
    field :contact_person, :string
    field :company_name, :string
    field :already_emailed, Ecto.Enum, values: @already_emailed_values, default: :pending
    field :draft_subject, :string
    field :draft_body, :string
    field :drafted_at, :utc_datetime
    field :sent_at, :utc_datetime
    field :last_error, :string

    timestamps(type: :utc_datetime)
  end

  @required_fields [:email_address, :contact_person, :company_name]
  @optional_fields [
    :already_emailed,
    :draft_subject,
    :draft_body,
    :drafted_at,
    :sent_at,
    :last_error
  ]

  @doc false
  def changeset(lead, attrs) do
    lead
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_format(:email_address, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/,
      message: "must be a valid email address"
    )
    |> validate_length(:contact_person, min: 1, max: 255)
    |> validate_length(:company_name, min: 1, max: 255)
    |> unique_constraint(:email_address)
  end

  # Focused changesets per transition — safer than one giant changeset

  def status_changeset(lead, status) when status in @already_emailed_values do
    lead
    |> change(already_emailed: status)
    |> validate_status_transition(lead.already_emailed, status)
  end

  def drafted_changeset(lead, %{subject: subject, body: body}) do
    lead
    |> change(
      already_emailed: :awaiting_review,
      draft_subject: subject,
      draft_body: body,
      drafted_at: DateTime.utc_now() |> DateTime.truncate(:second)
    )
  end

  def sent_changeset(lead) do
    lead
    |> change(already_emailed: :sent, sent_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def error_changeset(lead, reason) do
    lead
    |> change(already_emailed: :failed, last_error: inspect(reason))
  end

  # Guard against illegal state transitions
  @valid_transitions %{
    pending: [:drafting],
    drafting: [:awaiting_review, :failed, :pending],
    awaiting_review: [:approved, :pending],
    approved: [:sent, :failed],
    sent: [],
    failed: [:pending]
  }

  defp validate_status_transition(changeset, from, to) do
    allowed = Map.get(@valid_transitions, from, [])

    if to in allowed do
      changeset
    else
      add_error(changeset, :already_emailed, "cannot transition from #{from} to #{to}")
    end
  end
end
