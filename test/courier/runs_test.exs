defmodule Courier.RunsTest do
  use Courier.DataCase, async: false
  import Courier.Fixtures

  alias Courier.Runs
  alias Courier.Runs.Run

  describe "list_runs/1" do
    test "returns all runs" do
      r1 = run_fixture()
      r2 = run_fixture()
      ids = Runs.list_runs() |> Enum.map(& &1.id)
      assert r1.id in ids
      assert r2.id in ids
    end

    test "respects limit" do
      for _ <- 1..5, do: run_fixture()
      assert length(Runs.list_runs(3)) == 3
    end
  end

  describe "list_runs_for_recipe/1" do
    test "returns runs for a specific recipe" do
      r = run_fixture()
      run_fixture()
      results = Runs.list_runs_for_recipe(r.recipe_id)
      assert Enum.all?(results, &(&1.recipe_id == r.recipe_id))
    end
  end

  describe "get_run!/1" do
    test "returns run with preloads" do
      run = run_fixture()
      result = Runs.get_run!(run.id)
      assert result.recipe != nil
      assert result.device != nil
    end

    test "raises on missing id" do
      assert_raise Ecto.NoResultsError, fn -> Runs.get_run!(0) end
    end
  end

  describe "create_run/1" do
    test "creates with valid attrs" do
      recipe = recipe_fixture()
      device = device_fixture()
      assert {:ok, %Run{status: "pending"}} =
               Runs.create_run(%{recipe_id: recipe.id, device_id: device.id, status: "pending"})
    end

    test "returns error for invalid status" do
      recipe = recipe_fixture()
      device = device_fixture()
      assert {:error, cs} =
               Runs.create_run(%{recipe_id: recipe.id, device_id: device.id, status: "bad"})
      assert errors_on(cs).status != []
    end
  end

  describe "update_run/2" do
    test "updates status and log output" do
      run = run_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, updated} =
               Runs.update_run(run, %{
                 status: "success",
                 finished_at: now,
                 log_output: "done",
                 article_count: 3
               })

      assert updated.status == "success"
      assert updated.article_count == 3
    end
  end

  describe "change_run/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = Runs.change_run(%Run{})
    end
  end

  describe "mark_stale_runs_as_failed/0" do
    test "marks running runs as failure" do
      recipe = recipe_fixture()
      device = device_fixture()
      {:ok, run} = Runs.create_run(%{recipe_id: recipe.id, device_id: device.id, status: "running"})

      Runs.mark_stale_runs_as_failed()

      updated = Runs.get_run!(run.id)
      assert updated.status == "failure"
      assert updated.log_output =~ "interrupted"
    end

    test "does not affect non-running runs" do
      run = run_fixture(%{status: "success"})
      Runs.mark_stale_runs_as_failed()
      assert Runs.get_run!(run.id).status == "success"
    end
  end
end
