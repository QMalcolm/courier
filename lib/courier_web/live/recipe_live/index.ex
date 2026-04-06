defmodule CourierWeb.RecipeLive.Index do
  use CourierWeb, :live_view

  alias Courier.Library
  alias Courier.Library.Recipe

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :recipes, Library.list_recipes())}
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
    |> assign(:recipe, %Recipe{oldest_article: 7, max_articles: 25})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Recipe")
    |> assign(:recipe, Library.get_recipe!(id))
  end

  @impl true
  def handle_info({CourierWeb.RecipeLive.FormComponent, {:saved, _recipe}}, socket) do
    {:noreply, assign(socket, :recipes, Library.list_recipes())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    recipe = Library.get_recipe!(id)
    {:ok, _} = Library.delete_recipe(recipe)
    {:noreply, assign(socket, :recipes, Library.list_recipes())}
  end
end
