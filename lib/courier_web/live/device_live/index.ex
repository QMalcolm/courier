defmodule CourierWeb.DeviceLive.Index do
  use CourierWeb, :live_view

  alias Courier.Devices
  alias Courier.Devices.Device

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
end
