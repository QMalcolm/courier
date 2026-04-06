defmodule Courier.Repo.Migrations.CreateSchedules do
  use Ecto.Migration

  def change do
    create table(:schedules) do
      add :label, :string
      add :hour, :integer, null: false
      add :minute, :integer, null: false
      add :days, :string, null: false
      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end
  end
end
