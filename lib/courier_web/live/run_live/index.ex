defmodule CourierWeb.RunLive.Index do
  use CourierWeb, :live_view

  alias Courier.Runs

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Courier.PubSub, "runs")
    end

    {:ok,
     socket
     |> assign(:page_title, "Logs")
     |> assign(:runs, Runs.list_runs())}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:run_updated, _run}, socket) do
    {:noreply, assign(socket, :runs, Runs.list_runs())}
  end

  def status_class("success"), do: "bg-green-100 text-green-800"
  def status_class("failure"), do: "bg-red-100 text-red-800"
  def status_class("running"), do: "bg-blue-100 text-blue-800"
  def status_class(_), do: "bg-zinc-100 text-zinc-600"

  def duration(%{started_at: nil}), do: "—"
  def duration(%{finished_at: nil}), do: "running…"

  def duration(%{started_at: started_at, finished_at: finished_at}) do
    diff = DateTime.diff(finished_at, started_at, :second)
    "#{diff}s"
  end
end
