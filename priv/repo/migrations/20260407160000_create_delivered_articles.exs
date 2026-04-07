defmodule Courier.Repo.Migrations.CreateDeliveredArticles do
  use Ecto.Migration

  def change do
    create table(:delivered_articles) do
      add :recipe_id, references(:recipes, on_delete: :delete_all), null: false
      add :article_guid, :string, null: false
      add :delivered_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:delivered_articles, [:recipe_id, :article_guid])
    create index(:delivered_articles, [:recipe_id])
  end
end
