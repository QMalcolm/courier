defmodule CourierWeb.ScheduleLive.Index do
  use CourierWeb, :live_view

  alias Courier.Schedules
  alias Courier.Schedules.Schedule

  @days [{"Mon", "mon"}, {"Tue", "tue"}, {"Wed", "wed"}, {"Thu", "thu"},
         {"Fri", "fri"}, {"Sat", "sat"}, {"Sun", "sun"}]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:schedules, Schedules.list_schedules())
     |> assign(:days, @days)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    action = socket.assigns.live_action

    {:noreply,
     socket
     |> assign(:page_title, if(action == :new, do: "New Schedule", else: "Schedule"))
     |> assign(:form, blank_form())}
  end

  @impl true
  def handle_event("validate", %{"schedule" => params}, socket) do
    changeset = Schedule.changeset(%Schedule{}, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"schedule" => params}, socket) do
    case Schedules.create_schedule(params) do
      {:ok, _schedule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Schedule created")
         |> assign(:schedules, Schedules.list_schedules())
         |> push_patch(to: ~p"/schedule")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("toggle", %{"id" => id}, socket) do
    schedule = Schedules.get_schedule!(id)
    {:ok, _} = Schedules.update_schedule(schedule, %{enabled: !schedule.enabled})
    {:noreply, assign(socket, :schedules, Schedules.list_schedules())}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    schedule = Schedules.get_schedule!(id)
    {:ok, _} = Schedules.delete_schedule(schedule)
    {:noreply, assign(socket, :schedules, Schedules.list_schedules())}
  end

  defp blank_form do
    to_form(Schedule.changeset(%Schedule{hour: 7, minute: 0, days: "mon,tue,wed,thu,fri"}, %{}))
  end

  def day_checked?(form_or_schedule, day) do
    days =
      case form_or_schedule do
        %Phoenix.HTML.Form{} ->
          Phoenix.HTML.Form.input_value(form_or_schedule, :days) || ""

        %Schedule{} = s ->
          s.days || ""
      end

    day in String.split(days, ",", trim: true)
  end

  def format_time(%Schedule{hour: h, minute: m}) do
    :io_lib.format("~2..0B:~2..0B", [h, m]) |> IO.iodata_to_binary()
  end

  def format_days(%Schedule{} = schedule) do
    schedule
    |> Schedule.days_list()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(", ")
  end
end
