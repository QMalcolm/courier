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
    |> validate_source_yaml()
  end

  @doc """
  Generates a Calibre-compatible Python recipe from the recipe struct.

  `title`, `oldest_article`, and `max_articles` come from the DB fields.
  Everything else (`feeds`, `description`, `language`, `auto_cleanup`,
  `no_stylesheets`, `use_embedded_content`) is read from the YAML source.
  """
  def to_python(%__MODULE__{} = recipe) do
    {:ok, config} = YamlElixir.read_from_string(recipe.source)

    feeds_lines =
      config
      |> Map.get("feeds", [])
      |> Enum.map_join("\n", fn %{"name" => name, "url" => url} ->
        "        ('#{esc(name)}', '#{esc(url)}'),"
      end)

    description = esc(Map.get(config, "description", ""))
    language = Map.get(config, "language", "en")
    auto_cleanup = py_bool(Map.get(config, "auto_cleanup", true))
    no_stylesheets = py_bool(Map.get(config, "no_stylesheets", true))
    use_embedded_content = py_bool(Map.get(config, "use_embedded_content", false))

    [
      "from calibre.web.feeds.news import BasicNewsRecipe\n\n\n",
      "class GeneratedRecipe(BasicNewsRecipe):\n",
      "    title                 = '#{esc(recipe.name)}'\n",
      "    description           = '#{description}'\n",
      "    language              = '#{language}'\n",
      "    oldest_article        = #{recipe.oldest_article}\n",
      "    max_articles_per_feed = #{recipe.max_articles}\n",
      "    auto_cleanup          = #{auto_cleanup}\n",
      "    no_stylesheets        = #{no_stylesheets}\n",
      "    use_embedded_content  = #{use_embedded_content}\n\n",
      "    feeds = [\n",
      feeds_lines, "\n",
      "    ]\n"
    ]
    |> IO.iodata_to_binary()
  end

  defp validate_source_yaml(changeset) do
    validate_change(changeset, :source, fn :source, source ->
      case YamlElixir.read_from_string(source) do
        {:ok, %{"feeds" => feeds}} when is_list(feeds) and length(feeds) > 0 ->
          invalid =
            Enum.find(feeds, fn feed ->
              not (is_map(feed) and is_binary(Map.get(feed, "name")) and
                     is_binary(Map.get(feed, "url")))
            end)

          if invalid, do: [source: "each feed must have a name and url"], else: []

        {:ok, _} ->
          [source: "must include at least one feed with a name and url"]

        {:error, _} ->
          [source: "must be valid YAML"]
      end
    end)
  end

  defp esc(str), do: String.replace(str, "'", "\\'")
  defp py_bool(true), do: "True"
  defp py_bool(false), do: "False"
  defp py_bool(nil), do: "True"
end
