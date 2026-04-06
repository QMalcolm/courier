defmodule Courier.Library.Recipe do
  use Ecto.Schema
  import Ecto.Changeset

  schema "recipes" do
    field :name, :string
    field :slug, :string
    field :source, :string
    field :oldest_article, :integer, default: 7
    field :max_articles, :integer, default: 25

    has_many :subscriptions, Courier.Subscriptions.Subscription
    has_many :runs, Courier.Runs.Run

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(recipe, attrs) do
    recipe
    |> cast(attrs, [:name, :slug, :source, :oldest_article, :max_articles])
    |> validate_required([:name, :slug, :source])
    |> validate_number(:oldest_article, greater_than: 0)
    |> validate_number(:max_articles, greater_than: 0)
    |> unique_constraint(:slug)
  end
end
