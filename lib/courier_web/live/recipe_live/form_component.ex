defmodule CourierWeb.RecipeLive.FormComponent do
  use CourierWeb, :live_component

  alias Courier.Library

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
      </.header>

      <.simple_form
        for={@form}
        id="recipe-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:name]} type="text" label="Name" />
          <.input field={@form[:slug]} type="text" label="Slug" />
        </div>
        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:oldest_article]} type="number" label="Oldest article (days)" min="1" />
          <.input field={@form[:max_articles]} type="number" label="Max articles" min="1" />
        </div>
        <div>
          <label class="block text-sm font-semibold leading-6 text-zinc-800 mb-1">Source</label>
          <div id="recipe-source-editor" phx-update="ignore"></div>
          <textarea
            id="recipe-source"
            name={@form[:source].name}
            phx-hook="CodeEditor"
            phx-debounce="500"
            class="hidden"
          ><%= Phoenix.HTML.Form.normalize_value("textarea", @form[:source].value) %></textarea>
          <.error :for={msg <- Enum.map(@form[:source].errors, &translate_error(&1))}>{msg}</.error>
        </div>
        <div :if={is_list(@feed_check_results)} class="rounded-lg border border-zinc-200 divide-y divide-zinc-100">
          <div :if={@feed_check_results == []} class="px-3 py-2 text-sm text-zinc-500">
            No valid feeds found in source YAML.
          </div>
          <div :for={r <- @feed_check_results} class="flex items-start gap-2 px-3 py-2 text-sm">
            <span class={["font-bold mt-0.5", if(r.ok, do: "text-green-600", else: "text-red-600")]}>
              {if r.ok, do: "✓", else: "✗"}
            </span>
            <div>
              <span class="font-medium text-zinc-800">{r.name}</span>
              <span class={["ml-1", if(r.ok, do: "text-zinc-500", else: "text-red-600")]}>
                — {r.detail}
              </span>
            </div>
          </div>
        </div>
        <:actions>
          <button
            type="button"
            phx-click="check_feeds"
            phx-target={@myself}
            disabled={@feed_check_results == :checking}
            class={[
              "rounded-lg border py-2 px-3 text-sm font-semibold leading-6",
              if(@feed_check_results == :checking,
                do: "bg-zinc-100 border-zinc-200 text-zinc-400 cursor-not-allowed",
                else: "bg-white hover:bg-zinc-50 border-zinc-300 text-zinc-900"
              )
            ]}
          >
            {if @feed_check_results == :checking, do: "Checking...", else: "Check Feeds"}
          </button>
          <.button phx-disable-with="Saving...">Save Recipe</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{recipe: recipe} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn -> to_form(Library.change_recipe(recipe)) end)
     |> assign_new(:feed_check_results, fn -> nil end)
     |> assign_new(:current_params, fn -> %{"source" => recipe.source || ""} end)}
  end

  @impl true
  def handle_event("validate", %{"recipe" => recipe_params}, socket) do
    changeset = Library.change_recipe(socket.assigns.recipe, recipe_params)

    {:noreply,
     socket
     |> assign(form: to_form(changeset, action: :validate))
     |> assign(current_params: recipe_params)
     |> assign(feed_check_results: nil)}
  end

  def handle_event("check_feeds", _params, socket) do
    params = socket.assigns.current_params

    {:noreply,
     socket
     |> assign(feed_check_results: :checking)
     |> start_async(:check_feeds, fn -> Library.check_feeds_detailed(params) end)}
  end

  def handle_event("save", %{"recipe" => recipe_params}, socket) do
    save_recipe(socket, socket.assigns.action, recipe_params)
  end

  @impl true
  def handle_async(:check_feeds, {:ok, results}, socket) do
    {:noreply, assign(socket, feed_check_results: results)}
  end

  def handle_async(:check_feeds, {:exit, _reason}, socket) do
    {:noreply, assign(socket, feed_check_results: [])}
  end

  defp save_recipe(socket, :edit, recipe_params) do
    case Library.update_recipe(socket.assigns.recipe, recipe_params) do
      {:ok, recipe} ->
        notify_parent({:saved, recipe})

        {:noreply,
         socket
         |> put_flash(:info, "Recipe updated")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_recipe(socket, :new, recipe_params) do
    case Library.create_recipe(recipe_params) do
      {:ok, recipe} ->
        notify_parent({:saved, recipe})

        {:noreply,
         socket
         |> put_flash(:info, "Recipe created")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
