defmodule Courier.Schedules do
  import Ecto.Query
  require Logger

  alias Courier.Repo
  alias Courier.Schedules.Schedule

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
      |> Quantum.Job.set_task({Courier.Runner, :run_all_enabled, []})

    Courier.Scheduler.add_job(job)
    Logger.info("[Schedules] Registered job #{job_name(schedule)} — #{cron} #{timezone}")
  end

  defp remove_quantum_job(%Schedule{} = schedule) do
    Courier.Scheduler.delete_job(job_name(schedule))
    Logger.info("[Schedules] Removed job #{job_name(schedule)}")
  end

  defp job_name(%Schedule{id: id}), do: :"schedule_#{id}"
end
