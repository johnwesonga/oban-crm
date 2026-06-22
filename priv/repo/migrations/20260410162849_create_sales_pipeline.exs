defmodule Crm.Repo.Migrations.CreateSalesPipeline do
  use Ecto.Migration

  def change do
    create table(:sales_pipeline) do
      add :email_address, :string
      add :contact_person, :string
      add :company_name, :string
      add :already_emailed, :string
      add :drafted_at, :utc_datetime
      add :sent_at, :utc_datetime
      add :last_error, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sales_pipeline, [:email_address])

    # Partial index — makes the ScanPipelineWorker query very fast
    # even with millions of rows, since :pending leads will be a small subset
    create index(:sales_pipeline, [:already_emailed],
             where: "already_emailed = 'pending'",
             name: :sales_pipeline_pending_index
           )
  end
end
