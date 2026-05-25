defmodule CourierWeb.EbookLive.Show do
  use CourierWeb, :live_view

  alias Courier.Devices
  alias Courier.Ebooks
  alias Courier.EbookRunner

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    ebook = Ebooks.get_ebook!(id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Courier.PubSub, "ebooks")
    end

    {:ok,
     socket
     |> assign(:page_title, ebook.title)
     |> assign(:ebook, ebook)
     |> assign(:devices, Devices.list_devices())
     |> assign(:sends_by_device, sends_by_device(ebook))}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:ebook_updated, %{id: id}}, socket) when id == socket.assigns.ebook.id do
    ebook = Ebooks.get_ebook!(id)

    {:noreply,
     socket |> assign(:ebook, ebook) |> assign(:sends_by_device, sends_by_device(ebook))}
  end

  def handle_info({:ebook_updated, _}, socket), do: {:noreply, socket}

  @impl true
  def handle_event("retry", _params, socket) do
    EbookRunner.create(socket.assigns.ebook)
    {:noreply, put_flash(socket, :info, "Retrying ebook creation…")}
  end

  @impl true
  def handle_event("send_to_device", %{"device_id" => device_id}, socket) do
    device = Devices.get_device!(String.to_integer(device_id))
    EbookRunner.send_to_device(socket.assigns.ebook, device)
    {:noreply, put_flash(socket, :info, "Sending to #{device.name}…")}
  end

  defp sends_by_device(%{sends: sends}) do
    sends
    |> Enum.group_by(& &1.device_id)
    |> Map.new(fn {device_id, device_sends} ->
      latest = Enum.max_by(device_sends, & &1.inserted_at, DateTime)
      {device_id, latest}
    end)
  end

  def send_running?(nil), do: false
  def send_running?(%{status: "running"}), do: true
  def send_running?(_), do: false

  def already_sent?(nil), do: false
  def already_sent?(%{status: "success"}), do: true
  def already_sent?(_), do: false

  def send_label(nil), do: "Not sent"
  def send_label(%{status: "running"}), do: "Sending…"
  def send_label(%{status: "success", sent_at: nil}), do: "Sent"

  def send_label(%{status: "success", sent_at: at}) do
    "Sent #{Calendar.strftime(at, "%b %d %H:%M")}"
  end

  def send_label(%{status: "failure"}), do: "Send failed — retry?"

  def status_class("success"), do: "bg-green-100 text-green-800"
  def status_class("failure"), do: "bg-red-100 text-red-800"
  def status_class("running"), do: "bg-blue-100 text-blue-800"
  def status_class(_), do: "bg-zinc-100 text-zinc-600"

  def duration(%{started_at: nil}), do: nil
  def duration(%{finished_at: nil}), do: "running…"

  def duration(%{started_at: s, finished_at: f}) do
    "#{DateTime.diff(f, s, :second)}s"
  end
end
