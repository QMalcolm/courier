defmodule Courier.Repo.Migrations.CreateDevices do
  use Ecto.Migration

  def change do
    create table(:devices) do
      add :name, :string
      add :email, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:devices, [:email])
  end
end
