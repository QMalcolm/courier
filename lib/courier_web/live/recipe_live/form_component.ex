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
        <:actions>
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
     |> assign_new(:form, fn -> to_form(Library.change_recipe(recipe)) end)}
  end

  @impl true
  def handle_event("validate", %{"recipe" => recipe_params}, socket) do
    changeset = Library.change_recipe(socket.assigns.recipe, recipe_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"recipe" => recipe_params}, socket) do
    save_recipe(socket, socket.assigns.action, recipe_params)
  end

  defp save_recipe(socket, action, recipe_params) do
    changeset = Library.change_recipe(socket.assigns.recipe, recipe_params)

    if changeset.valid? do
      case Library.check_feeds(recipe_params) do
        :ok ->
          do_save(socket, action, recipe_params)

        {:error, bad_urls} ->
          changeset_with_errors =
            Enum.reduce(bad_urls, changeset, fn url, cs ->
              Ecto.Changeset.add_error(cs, :source, "could not reach feed: #{url}")
            end)

          {:noreply, assign(socket, form: to_form(changeset_with_errors, action: :validate))}
      end
    else
      do_save(socket, action, recipe_params)
    end
  end

  defp do_save(socket, :edit, recipe_params) do
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

  defp do_save(socket, :new, recipe_params) do
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
