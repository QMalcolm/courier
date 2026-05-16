defmodule Courier.Repo.Migrations.CreateEbookSends do
  use Ecto.Migration

  def change do
    create table(:ebook_sends) do
      add :ebook_id, references(:ebooks, on_delete: :delete_all), null: false
      add :device_id, references(:devices, on_delete: :delete_all), null: false
      add :status, :string, null: false
      add :sent_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:ebook_sends, [:ebook_id])
    create index(:ebook_sends, [:device_id])
  end
end
