defmodule Courier.Runs do
  import Ecto.Query
  alias Courier.Repo
  alias Courier.Runs.Run

  def list_runs(limit \\ 100) do
    Repo.all(
      from r in Run,
        order_by: [desc: r.inserted_at],
        limit: ^limit,
        preload: [:recipe, :device]
    )
  end

  def list_runs_for_recipe(recipe_id) do
    Repo.all(
      from r in Run,
        where: r.recipe_id == ^recipe_id,
        order_by: [desc: r.inserted_at],
        preload: [:device]
    )
  end

  def get_run!(id), do: Repo.get!(Run, id) |> Repo.preload([:recipe, :device])

  def create_run(attrs \\ %{}) do
    %Run{}
    |> Run.changeset(attrs)
    |> Repo.insert()
  end

  def update_run(%Run{} = run, attrs) do
    run
    |> Run.changeset(attrs)
    |> Repo.update()
  end

  def change_run(%Run{} = run, attrs \\ %{}) do
    Run.changeset(run, attrs)
  end

  @doc """
  Marks any runs still in "running" status as "failure".
  Called on application start to recover from crashes or ungraceful shutdowns
  that left run records stuck.
  """
  def mark_stale_runs_as_failed do
    now = DateTime.utc_now()

    Repo.update_all(
      from(r in Run, where: r.status == "running"),
      set: [
        status: "failure",
        finished_at: now,
        log_output: "Run was interrupted (server restarted while running)."
      ]
    )
  end
end
