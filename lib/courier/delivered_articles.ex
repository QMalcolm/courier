defmodule Courier.DeliveredArticles do
  import Ecto.Query

  alias Courier.DeliveredArticles.DeliveredArticle
  alias Courier.Repo

  @doc "Returns a MapSet of article GUIDs already delivered for the given recipe."
  def list_guids_for_recipe(recipe_id) do
    DeliveredArticle
    |> where([a], a.recipe_id == ^recipe_id)
    |> select([a], a.article_guid)
    |> Repo.all()
    |> MapSet.new()
  end

  @doc "Bulk-records delivered article GUIDs for the given recipe. Ignores conflicts."
  def record_articles(_recipe_id, []), do: {0, nil}

  def record_articles(recipe_id, guids) when is_list(guids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(guids, fn guid ->
        %{
          recipe_id: recipe_id,
          article_guid: guid,
          delivered_at: now,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(DeliveredArticle, entries,
      on_conflict: :nothing,
      conflict_target: [:recipe_id, :article_guid]
    )
  end
end
