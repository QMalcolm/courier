defmodule CourierWeb.RecipeLive.Index do
  use CourierWeb, :live_view

  alias Courier.Devices
  alias Courier.Library
  alias Courier.Library.Recipe
  alias Courier.Schedules
  alias Courier.Subscriptions

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

  defp apply_action(socket, :schedules, %{"id" => id}) do
    recipe = Library.get_recipe!(id)
    schedule_ids = Schedules.list_schedule_ids_for_recipe(id) |> MapSet.new()

    socket
    |> assign(:page_title, "Schedules — #{recipe.name}")
    |> assign(:recipe, recipe)
    |> assign(:all_schedules, Schedules.list_schedules())
    |> assign(:schedule_ids, schedule_ids)
  end

  defp apply_action(socket, :subscriptions, %{"id" => id}) do
    recipe = Library.get_recipe!(id)
    subscriptions = Subscriptions.list_subscriptions_for_recipe(id)
    subscribed_ids = MapSet.new(subscriptions, & &1.device_id)

    socket
    |> assign(:page_title, "Devices — #{recipe.name}")
    |> assign(:recipe, recipe)
    |> assign(:all_devices, Devices.list_devices())
    |> assign(:subscribed_ids, subscribed_ids)
  end

  @impl true
  def handle_info({CourierWeb.RecipeLive.FormComponent, {:saved, _recipe}}, socket) do
    {:noreply,
     socket
     |> assign(:recipes, Library.list_recipes())
     |> assign(:scheduled_recipe_ids, Schedules.list_scheduled_recipe_ids())}
  end

  @impl true
  def handle_event("toggle_schedule", %{"schedule_id" => schedule_id}, socket) do
    recipe = socket.assigns.recipe
    schedule_id = String.to_integer(schedule_id)

    schedule_ids = Schedules.toggle_recipe(schedule_id, recipe.id, socket.assigns.schedule_ids)

    {:noreply,
     socket
     |> assign(:schedule_ids, schedule_ids)
     |> assign(:scheduled_recipe_ids, Schedules.list_scheduled_recipe_ids())
     |> put_flash(:info, "Saved")}
  end

  @impl true
  def handle_event("toggle_subscription", %{"device_id" => device_id}, socket) do
    recipe = socket.assigns.recipe
    device_id = String.to_integer(device_id)

    subscribed_ids =
      case Subscriptions.get_subscription_by_device_and_recipe(device_id, recipe.id) do
        nil ->
          {:ok, _} = Subscriptions.create_subscription(%{device_id: device_id, recipe_id: recipe.id})
          MapSet.put(socket.assigns.subscribed_ids, device_id)

        subscription ->
          {:ok, _} = Subscriptions.delete_subscription(subscription)
          MapSet.delete(socket.assigns.subscribed_ids, device_id)
      end

    {:noreply,
     socket
     |> assign(:subscribed_ids, subscribed_ids)
     |> put_flash(:info, "Saved")}
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
