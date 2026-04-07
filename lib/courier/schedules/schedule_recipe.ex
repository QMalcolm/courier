defmodule Courier.Schedules.ScheduleRecipe do
  use Ecto.Schema
  import Ecto.Changeset

  schema "schedule_recipes" do
    belongs_to :schedule, Courier.Schedules.Schedule
    belongs_to :recipe, Courier.Library.Recipe

    timestamps(type: :utc_datetime)
  end

  def changeset(sr, attrs) do
    sr
    |> cast(attrs, [:schedule_id, :recipe_id])
    |> validate_required([:schedule_id, :recipe_id])
    |> unique_constraint([:schedule_id, :recipe_id])
  end
end
