defmodule CourierWeb.DeviceLive.Index do
  use CourierWeb, :live_view

  alias Courier.Devices
  alias Courier.Devices.Device
  alias Courier.Library
  alias Courier.Subscriptions

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :devices, Devices.list_devices())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Devices")
    |> assign(:device, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Device")
    |> assign(:device, %Device{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Device")
    |> assign(:device, Devices.get_device!(id))
  end

  defp apply_action(socket, :subscriptions, %{"id" => id}) do
    device = Devices.get_device!(id)
    subscriptions = Subscriptions.list_subscriptions_for_device(id)
    subscribed_ids = MapSet.new(subscriptions, & &1.recipe_id)

    socket
    |> assign(:page_title, "Subscriptions — #{device.name}")
    |> assign(:device, device)
    |> assign(:all_recipes, Library.list_recipes())
    |> assign(:subscribed_ids, subscribed_ids)
  end

  @impl true
  def handle_info({CourierWeb.DeviceLive.FormComponent, {:saved, _device}}, socket) do
    {:noreply, assign(socket, :devices, Devices.list_devices())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    device = Devices.get_device!(id)
    {:ok, _} = Devices.delete_device(device)
    {:noreply, assign(socket, :devices, Devices.list_devices())}
  end

  def handle_event("toggle_subscription", %{"recipe_id" => recipe_id}, socket) do
    device = socket.assigns.device
    recipe_id = String.to_integer(recipe_id)

    subscribed_ids =
      case Subscriptions.get_subscription_by_device_and_recipe(device.id, recipe_id) do
        nil ->
          {:ok, _} = Subscriptions.create_subscription(%{device_id: device.id, recipe_id: recipe_id})
          MapSet.put(socket.assigns.subscribed_ids, recipe_id)

        subscription ->
          {:ok, _} = Subscriptions.delete_subscription(subscription)
          MapSet.delete(socket.assigns.subscribed_ids, recipe_id)
      end

    {:noreply,
     socket
     |> assign(:subscribed_ids, subscribed_ids)
     |> put_flash(:info, "Saved")}
  end
end
