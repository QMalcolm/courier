defmodule Courier.Schedules do
  import Ecto.Query
  require Logger

  alias Courier.Repo
  alias Courier.Schedules.Schedule
  alias Courier.Schedules.ScheduleRecipe

  def list_schedules do
    Repo.all(from s in Schedule, order_by: [s.hour, s.minute])
  end

  def get_schedule!(id), do: Repo.get!(Schedule, id)

  def create_schedule(attrs \\ %{}) do
    %Schedule{}
    |> Schedule.changeset(attrs)
    |> Repo.insert()
    |> tap_sync()
  end

  def update_schedule(%Schedule{} = schedule, attrs) do
    schedule
    |> Schedule.changeset(attrs)
    |> Repo.update()
    |> tap_sync()
  end

  def delete_schedule(%Schedule{} = schedule) do
    result = Repo.delete(schedule)
    remove_quantum_job(schedule)
    result
  end

  def change_schedule(%Schedule{} = schedule, attrs \\ %{}) do
    Schedule.changeset(schedule, attrs)
  end

  @doc "Returns all recipe IDs associated with the given schedule."
  def list_recipe_ids_for_schedule(schedule_id) do
    Repo.all(
      from sr in ScheduleRecipe,
        where: sr.schedule_id == ^schedule_id,
        select: sr.recipe_id
    )
  end

  @doc "Returns a MapSet of recipe IDs that have at least one schedule."
  def list_scheduled_recipe_ids do
    Repo.all(from sr in ScheduleRecipe, select: sr.recipe_id, distinct: true)
    |> MapSet.new()
  end

  @doc "Toggles a recipe association for a schedule, returning the updated recipe ID set."
  def toggle_recipe(schedule_id, recipe_id, current_ids) do
    case Repo.get_by(ScheduleRecipe, schedule_id: schedule_id, recipe_id: recipe_id) do
      nil ->
        {:ok, _} =
          %ScheduleRecipe{}
          |> ScheduleRecipe.changeset(%{schedule_id: schedule_id, recipe_id: recipe_id})
          |> Repo.insert()

        MapSet.put(current_ids, recipe_id)

      sr ->
        {:ok, _} = Repo.delete(sr)
        MapSet.delete(current_ids, recipe_id)
    end
  end

  @doc """
  Syncs all enabled schedules from the database into Quantum, replacing any
  previously registered schedule jobs. Called on application startup and
  after any schedule change.
  """
  def sync_quantum do
    existing = Courier.Scheduler.jobs()

    for {name, _job} <- existing,
        name |> to_string() |> String.starts_with?("schedule_") do
      Courier.Scheduler.delete_job(name)
    end

    list_schedules()
    |> Enum.filter(& &1.enabled)
    |> Enum.each(&add_quantum_job/1)
  end

  # --- private ---

  defp tap_sync({:ok, schedule} = result) do
    if schedule.enabled do
      add_quantum_job(schedule)
    else
      remove_quantum_job(schedule)
    end

    result
  end

  defp tap_sync(error), do: error

  defp add_quantum_job(%Schedule{} = schedule) do
    cron = Schedule.to_cron(schedule)
    timezone = schedule.timezone || "UTC"

    job =
      Courier.Scheduler.new_job()
      |> Quantum.Job.set_name(job_name(schedule))
      |> Quantum.Job.set_schedule(Crontab.CronExpression.Parser.parse!(cron))
      |> Quantum.Job.set_timezone(timezone)
      |> Quantum.Job.set_task({Courier.Runner, :run_for_schedule, [schedule.id]})

    Courier.Scheduler.add_job(job)
    Logger.info("[Schedules] Registered job #{job_name(schedule)} — #{cron} #{timezone}")
  end

  defp remove_quantum_job(%Schedule{} = schedule) do
    Courier.Scheduler.delete_job(job_name(schedule))
    Logger.info("[Schedules] Removed job #{job_name(schedule)}")
  end

  defp job_name(%Schedule{id: id}), do: :"schedule_#{id}"
end
