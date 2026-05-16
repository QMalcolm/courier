defmodule Courier.Repo.Migrations.CreateEbooks do
  use Ecto.Migration

  def change do
    create table(:ebooks) do
      add :title, :string, null: false
      add :status, :string, default: "pending", null: false
      add :log_output, :text
      add :archived, :boolean, default: false, null: false
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end
