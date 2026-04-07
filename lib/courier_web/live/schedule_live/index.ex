defmodule CourierWeb.ScheduleLive.Index do
  use CourierWeb, :live_view

  alias Courier.Library
  alias Courier.Schedules
  alias Courier.Schedules.Schedule

  @days [{"Mon", "mon"}, {"Tue", "tue"}, {"Wed", "wed"}, {"Thu", "thu"},
         {"Fri", "fri"}, {"Sat", "sat"}, {"Sun", "sun"}]

  @timezones [
    {"UTC", "UTC"},
    # Americas
    {"America/New_York", "Eastern Time (US & Canada)"},
    {"America/Chicago", "Central Time (US & Canada)"},
    {"America/Denver", "Mountain Time (US & Canada)"},
    {"America/Phoenix", "Arizona (no DST)"},
    {"America/Los_Angeles", "Pacific Time (US & Canada)"},
    {"America/Anchorage", "Alaska"},
    {"Pacific/Honolulu", "Hawaii"},
    {"America/Toronto", "Toronto"},
    {"America/Vancouver", "Vancouver"},
    {"America/Sao_Paulo", "Brasilia"},
    {"America/Mexico_City", "Mexico City"},
    # Europe
    {"Europe/London", "London"},
    {"Europe/Dublin", "Dublin"},
    {"Europe/Paris", "Paris"},
    {"Europe/Berlin", "Berlin"},
    {"Europe/Amsterdam", "Amsterdam"},
    {"Europe/Rome", "Rome"},
    {"Europe/Madrid", "Madrid"},
    {"Europe/Stockholm", "Stockholm"},
    {"Europe/Helsinki", "Helsinki"},
    {"Europe/Athens", "Athens"},
    {"Europe/Moscow", "Moscow"},
    # Asia / Pacific
    {"Asia/Dubai", "Dubai"},
    {"Asia/Kolkata", "Mumbai / Kolkata"},
    {"Asia/Bangkok", "Bangkok"},
    {"Asia/Singapore", "Singapore"},
    {"Asia/Shanghai", "Beijing / Shanghai"},
    {"Asia/Tokyo", "Tokyo"},
    {"Asia/Seoul", "Seoul"},
    {"Australia/Sydney", "Sydney"},
    {"Australia/Melbourne", "Melbourne"},
    {"Australia/Perth", "Perth"},
    {"Pacific/Auckland", "Auckland"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:schedules, Schedules.list_schedules())
     |> assign(:days, @days)
     |> assign(:timezones, @timezones)
     |> assign(:schedule, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Schedule")
    |> assign(:form, blank_form())
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Schedule")
    |> assign(:form, blank_form())
  end

  defp apply_action(socket, :recipes, %{"id" => id}) do
    schedule = Schedules.get_schedule!(id)
    recipe_ids = Schedules.list_recipe_ids_for_schedule(id) |> MapSet.new()

    socket
    |> assign(:page_title, "Recipes — #{schedule.label || format_time(schedule)}")
    |> assign(:schedule, schedule)
    |> assign(:all_recipes, Library.list_recipes())
    |> assign(:scheduled_recipe_ids, recipe_ids)
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

  def handle_event("toggle_recipe", %{"recipe_id" => recipe_id}, socket) do
    schedule = socket.assigns.schedule
    recipe_id = String.to_integer(recipe_id)

    scheduled_recipe_ids =
      Schedules.toggle_recipe(schedule.id, recipe_id, socket.assigns.scheduled_recipe_ids)

    {:noreply, assign(socket, :scheduled_recipe_ids, scheduled_recipe_ids)}
  end

  defp blank_form do
    to_form(Schedule.changeset(%Schedule{hour: 7, minute: 0, days: "mon,tue,wed,thu,fri", timezone: "UTC"}, %{}))
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

  def format_time(%Schedule{hour: h, minute: m, timezone: tz}) do
    time = :io_lib.format("~2..0B:~2..0B", [h, m]) |> IO.iodata_to_binary()
    "#{time} #{tz || "UTC"}"
  end

  def format_days(%Schedule{} = schedule) do
    schedule
    |> Schedule.days_list()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(", ")
  end
end
