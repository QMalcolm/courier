defmodule CourierWeb.RecipeLive.Index do
  use CourierWeb, :live_view

  alias Courier.Library
  alias Courier.Library.Recipe
  alias Courier.Schedules

  @recipe_template """
  feeds:
    - name: Feed Name
      url: https://example.com/rss

  # description: ""         # shown in the epub metadata
  # language: en            # ISO 639-1 language code
  # auto_cleanup: true      # strip boilerplate/navigation from articles
  # no_stylesheets: true    # remove CSS for a cleaner reading experience
  # use_embedded_content: false  # set true if the feed includes full article text
  """

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:recipes, Library.list_recipes())
     |> assign(:scheduled_recipe_ids, Schedules.list_scheduled_recipe_ids())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Recipes")
    |> assign(:recipe, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Recipe")
    |> assign(:recipe, %Recipe{oldest_article: 7, max_articles: 25, source: @recipe_template})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Recipe")
    |> assign(:recipe, Library.get_recipe!(id))
  end

  @impl true
  def handle_info({CourierWeb.RecipeLive.FormComponent, {:saved, _recipe}}, socket) do
    {:noreply,
     socket
     |> assign(:recipes, Library.list_recipes())
     |> assign(:scheduled_recipe_ids, Schedules.list_scheduled_recipe_ids())}
  end

  @impl true
  def handle_event("run_now", %{"id" => id}, socket) do
    Courier.Runner.run_recipe(id)
    {:noreply, put_flash(socket, :info, "Run started — check Logs for progress.")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    recipe = Library.get_recipe!(id)
    {:ok, _} = Library.delete_recipe(recipe)
    {:noreply, assign(socket, :recipes, Library.list_recipes())}
  end
end
