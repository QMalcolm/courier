defmodule CourierWeb.SubscriptionLive.Index do
  use CourierWeb, :live_view

  alias Courier.Subscriptions
  alias Courier.Subscriptions.Subscription
  alias Courier.Library
  alias Courier.Devices

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:subscriptions, Subscriptions.list_subscriptions())
     |> assign(:recipes, Library.list_recipes())
     |> assign(:devices, Devices.list_devices())}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    action = socket.assigns.live_action

    {:noreply,
     socket
     |> assign(:page_title, if(action == :new, do: "New Subscription", else: "Subscriptions"))
     |> assign(:form, new_form())}
  end

  @impl true
  def handle_event("toggle", %{"id" => id}, socket) do
    subscription = Subscriptions.get_subscription!(id)
    {:ok, _} = Subscriptions.update_subscription(subscription, %{enabled: !subscription.enabled})
    {:noreply, assign(socket, :subscriptions, Subscriptions.list_subscriptions())}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    subscription = Subscriptions.get_subscription!(id)
    {:ok, _} = Subscriptions.delete_subscription(subscription)
    {:noreply, assign(socket, :subscriptions, Subscriptions.list_subscriptions())}
  end

  def handle_event("save", %{"subscription" => params}, socket) do
    case Subscriptions.create_subscription(params) do
      {:ok, _subscription} ->
        {:noreply,
         socket
         |> put_flash(:info, "Subscription created")
         |> assign(:subscriptions, Subscriptions.list_subscriptions())
         |> push_patch(to: ~p"/subscriptions")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("validate", %{"subscription" => params}, socket) do
    changeset = Subscription.changeset(%Subscription{}, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  defp new_form do
    to_form(Subscription.changeset(%Subscription{}, %{}))
  end
end
