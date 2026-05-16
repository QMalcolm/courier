defmodule Courier.Repo.Migrations.CreateEbookArticles do
  use Ecto.Migration

  def change do
    create table(:ebook_articles) do
      add :ebook_id, references(:ebooks, on_delete: :delete_all), null: false
      add :url, :string, null: false
      add :title, :string
      add :position, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:ebook_articles, [:ebook_id])
  end
end
