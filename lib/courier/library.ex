defmodule Courier.Library do
  import Ecto.Query
  alias Courier.FeedParser
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

  @doc """
  Checks that every feed URL in the recipe params is reachable.
  Feed URLs are fetched in parallel. Returns :ok or {:error, [unreachable_urls]}.
  Fails open (returns :ok) if the source YAML is absent/invalid — let the
  changeset validator surface that error instead.
  """
  def check_feeds(%{"source" => source}) do
    case YamlElixir.read_from_string(source) do
      {:ok, %{"feeds" => feeds}} when is_list(feeds) ->
        urls =
          feeds
          |> Enum.filter(&is_map/1)
          |> Enum.map(& &1["url"])
          |> Enum.filter(&is_binary/1)

        bad_urls =
          urls
          |> Task.async_stream(&{&1, FeedParser.fetch_guids(&1)},
            timeout: 10_000,
            on_timeout: :kill_task
          )
          |> Enum.flat_map(fn
            {:ok, {url, {:error, _}}} -> [url]
            _ -> []
          end)

        if bad_urls == [], do: :ok, else: {:error, bad_urls}

      _ ->
        :ok
    end
  end

  def check_feeds(_), do: :ok
end
