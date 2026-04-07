defmodule Courier.Repo.Migrations.AddTimezoneToSchedules do
  use Ecto.Migration

  def change do
    alter table(:schedules) do
      add :timezone, :string, default: "UTC", null: false
    end
  end
end
