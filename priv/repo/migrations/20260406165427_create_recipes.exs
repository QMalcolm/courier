defmodule Courier.Repo.Migrations.CreateRecipes do
  use Ecto.Migration

  def change do
    create table(:recipes) do
      add :name, :string
      add :slug, :string
      add :source, :text
      add :oldest_article, :integer
      add :max_articles, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:recipes, [:slug])
  end
end
