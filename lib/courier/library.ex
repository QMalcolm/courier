defmodule Courier.Library do
  import Ecto.Query
  alias Courier.Repo
  alias Courier.Library.Recipe

  def list_recipes do
    Repo.all(from r in Recipe, order_by: r.name)
  end

  def get_recipe!(id), do: Repo.get!(Recipe, id)

  def get_recipe_by_slug!(slug), do: Repo.get_by!(Recipe, slug: slug)

  def create_recipe(attrs \\ %{}) do
    %Recipe{}
    |> Recipe.changeset(attrs)
    |> Repo.insert()
  end

  def update_recipe(%Recipe{} = recipe, attrs) do
    recipe
    |> Recipe.changeset(attrs)
    |> Repo.update()
  end

  def delete_recipe(%Recipe{} = recipe), do: Repo.delete(recipe)

  def change_recipe(%Recipe{} = recipe, attrs \\ %{}) do
    Recipe.changeset(recipe, attrs)
  end
end
