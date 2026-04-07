defmodule Courier.DeliveredArticles.DeliveredArticle do
  use Ecto.Schema
  import Ecto.Changeset

  schema "delivered_articles" do
    field :article_guid, :string
    field :delivered_at, :utc_datetime

    belongs_to :recipe, Courier.Library.Recipe

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(article, attrs) do
    article
    |> cast(attrs, [:recipe_id, :article_guid, :delivered_at])
    |> validate_required([:recipe_id, :article_guid, :delivered_at])
    |> unique_constraint([:recipe_id, :article_guid])
  end
end
