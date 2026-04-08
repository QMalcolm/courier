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
    {"Eastern Time (US & Canada)", "America/New_York"},
    {"Central Time (US & Canada)", "America/Chicago"},
    {"Mountain Time (US & Canada)", "America/Denver"},
    {"Arizona (no DST)", "America/Phoenix"},
    {"Pacific Time (US & Canada)", "America/Los_Angeles"},
    {"Alaska", "America/Anchorage"},
    {"Hawaii", "Pacific/Honolulu"},
    {"Toronto", "America/Toronto"},
    {"Vancouver", "America/Vancouver"},
    {"Brasilia", "America/Sao_Paulo"},
    {"Mexico City", "America/Mexico_City"},
    # Europe
    {"London", "Europe/London"},
    {"Dublin", "Europe/Dublin"},
    {"Paris", "Europe/Paris"},
    {"Berlin", "Europe/Berlin"},
    {"Amsterdam", "Europe/Amsterdam"},
    {"Rome", "Europe/Rome"},
    {"Madrid", "Europe/Madrid"},
    {"Stockholm", "Europe/Stockholm"},
    {"Helsinki", "Europe/Helsinki"},
    {"Athens", "Europe/Athens"},
    {"Moscow", "Europe/Moscow"},
    # Asia / Pacific
    {"Dubai", "Asia/Dubai"},
    {"Mumbai / Kolkata", "Asia/Kolkata"},
    {"Bangkok", "Asia/Bangkok"},
    {"Singapore", "Asia/Singapore"},
    {"Beijing / Shanghai", "Asia/Shanghai"},
    {"Tokyo", "Asia/Tokyo"},
    {"Seoul", "Asia/Seoul"},
    {"Sydney", "Australia/Sydney"},
    {"Melbourne", "Australia/Melbourne"},
    {"Perth", "Australia/Perth"},
    {"Auckland", "Pacific/Auckland"}
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

  defp apply_action(socket, :edit, %{"id" => id}) do
    schedule = Schedules.get_schedule!(id)

    socket
    |> assign(:page_title, "Edit Schedule")
    |> assign(:schedule, schedule)
    |> assign(:form, to_form(Schedule.changeset(schedule, %{})))
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
    result =
      case socket.assigns.live_action do
        :edit -> Schedules.update_schedule(socket.assigns.schedule, params)
        :new -> Schedules.create_schedule(params)
      end

    case result do
      {:ok, _schedule} ->
        {:noreply,
         socket
         |> put_flash(:info, if(socket.assigns.live_action == :edit, do: "Schedule updated", else: "Schedule created"))
         |> assign(:schedules, Schedules.list_schedules())
         |> push_patch(to: ~p"/schedule")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("toggle", %{"id" => id}, socket) do
    schedule = Schedules.get_schedule!(id)
    {:ok, _} = Schedules.update_schedule(schedule, %{enabled: !schedule.enabled})

    {:noreply,
     socket
     |> assign(:schedules, Schedules.list_schedules())
     |> put_flash(:info, "Saved")}
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

    {:noreply,
     socket
     |> assign(:scheduled_recipe_ids, scheduled_recipe_ids)
     |> put_flash(:info, "Saved")}
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
