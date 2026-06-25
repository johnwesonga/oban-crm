defmodule Crm.Repo.Migrations.AddCompanyContextToSalesPipeline do
  use Ecto.Migration

  def change do
    alter table(:sales_pipeline) do
      add :company_context, :text
    end
  end
end
