defmodule Courier.Repo.Migrations.CreateScheduleRecipes do
  use Ecto.Migration

  def change do
    create table(:schedule_recipes) do
      add :schedule_id, references(:schedules, on_delete: :delete_all), null: false
      add :recipe_id, references(:recipes, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:schedule_recipes, [:schedule_id, :recipe_id])
    create index(:schedule_recipes, [:recipe_id])
  end
end
