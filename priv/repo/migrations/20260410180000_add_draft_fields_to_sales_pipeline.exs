defmodule Crm.Repo.Migrations.AddDraftFieldsToSalesPipeline do
  use Ecto.Migration

  def change do
    alter table(:sales_pipeline) do
      add :draft_subject, :text
      add :draft_body, :text
    end
  end
end
