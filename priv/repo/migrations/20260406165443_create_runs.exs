defmodule Courier.Repo.Migrations.CreateRuns do
  use Ecto.Migration

  def change do
    create table(:runs) do
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      add :status, :string, null: false, default: "pending"
      add :log_output, :text
      add :recipe_id, references(:recipes, on_delete: :delete_all)
      add :device_id, references(:devices, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:runs, [:recipe_id])
    create index(:runs, [:device_id])
  end
end
