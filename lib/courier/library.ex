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
  Checks every feed URL in the recipe params and returns per-feed results.
  Feeds are fetched in parallel. Each result is a map with:
    %{name: string, url: string, ok: boolean, detail: string}
  Returns [] if source YAML is absent or invalid.
  """
  def check_feeds_detailed(%{"source" => source}) do
    case YamlElixir.read_from_string(source) do
      {:ok, %{"feeds" => feeds}} when is_list(feeds) ->
        valid_feeds =
          Enum.filter(feeds, &(is_map(&1) and is_binary(&1["name"]) and is_binary(&1["url"])))

        valid_feeds
        |> Task.async_stream(
          fn feed ->
            name = feed["name"]
            url = feed["url"]

            case FeedParser.fetch_guids(url) do
              {:ok, guids} -> %{name: name, url: url, ok: true, detail: article_label(length(guids))}
              {:error, reason} -> %{name: name, url: url, ok: false, detail: reason}
            end
          end,
          timeout: 10_000,
          on_timeout: :kill_task
        )
        |> Enum.zip(valid_feeds)
        |> Enum.map(fn
          {{:ok, result}, _feed} -> result
          {{:exit, _}, feed} -> %{name: feed["name"], url: feed["url"], ok: false, detail: "timed out"}
        end)

      _ ->
        []
    end
  end

  def check_feeds_detailed(_), do: []

  defp article_label(1), do: "1 article found"
  defp article_label(n), do: "#{n} articles found"
end
