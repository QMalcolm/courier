defmodule Courier.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions) do
      add :enabled, :boolean, default: true, null: false
      add :recipe_id, references(:recipes, on_delete: :delete_all)
      add :device_id, references(:devices, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:subscriptions, [:recipe_id])
    create index(:subscriptions, [:device_id])
    create unique_index(:subscriptions, [:recipe_id, :device_id])
  end
end
