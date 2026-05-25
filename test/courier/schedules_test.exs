defmodule Courier.SchedulesTest do
  use Courier.DataCase, async: false
  import Courier.Fixtures

  alias Courier.Schedules
  alias Courier.Schedules.Schedule

  describe "list_schedules/0" do
    test "returns schedules ordered by hour and minute" do
      schedule_fixture(%{hour: 10, minute: 0, days: "mon"})
      schedule_fixture(%{hour: 7, minute: 30, days: "fri"})
      [first | _] = Schedules.list_schedules()
      assert first.hour == 7
    end
  end

  describe "get_schedule!/1" do
    test "returns the schedule" do
      s = schedule_fixture()
      assert Schedules.get_schedule!(s.id).id == s.id
    end

    test "raises on missing id" do
      assert_raise Ecto.NoResultsError, fn -> Schedules.get_schedule!(0) end
    end
  end

  describe "create_schedule/1" do
    test "creates with valid attrs" do
      assert {:ok, %Schedule{hour: 8, minute: 0, days: "mon,fri"}} =
               Schedules.create_schedule(%{hour: 8, minute: 0, days: "mon,fri", timezone: "UTC"})
    end

    test "normalizes checkbox-style days list" do
      assert {:ok, s} =
               Schedules.create_schedule(%{
                 "hour" => 9,
                 "minute" => 0,
                 "days" => ["mon", "wed", "fri"],
                 "timezone" => "UTC"
               })

      assert s.days == "mon,wed,fri"
    end

    test "returns error for missing hour" do
      assert {:error, cs} = Schedules.create_schedule(%{minute: 0, days: "mon", timezone: "UTC"})
      assert "can't be blank" in errors_on(cs).hour
    end

    test "returns error for out-of-range hour" do
      assert {:error, cs} = Schedules.create_schedule(%{hour: 25, minute: 0, days: "mon", timezone: "UTC"})
      assert errors_on(cs).hour != []
    end

    test "returns error for empty days" do
      assert {:error, cs} = Schedules.create_schedule(%{hour: 8, minute: 0, days: "", timezone: "UTC"})
      assert errors_on(cs).days != []
    end
  end

  describe "update_schedule/2" do
    test "updates the schedule" do
      s = schedule_fixture()
      assert {:ok, updated} = Schedules.update_schedule(s, %{label: "Morning"})
      assert updated.label == "Morning"
    end

    test "disabling removes quantum job without error" do
      s = schedule_fixture(%{enabled: true})
      assert {:ok, updated} = Schedules.update_schedule(s, %{enabled: false})
      assert updated.enabled == false
    end
  end

  describe "delete_schedule/1" do
    test "deletes the schedule" do
      s = schedule_fixture()
      assert {:ok, _} = Schedules.delete_schedule(s)
      assert_raise Ecto.NoResultsError, fn -> Schedules.get_schedule!(s.id) end
    end
  end

  describe "change_schedule/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = Schedules.change_schedule(%Schedule{})
    end
  end

  describe "list_schedule_ids_for_recipe/1" do
    test "returns schedule ids associated with a recipe" do
      recipe = recipe_fixture()
      s = schedule_fixture()
      Schedules.toggle_recipe(s.id, recipe.id, MapSet.new())
      ids = Schedules.list_schedule_ids_for_recipe(recipe.id)
      assert s.id in ids
    end
  end

  describe "list_recipe_ids_for_schedule/1" do
    test "returns recipe ids associated with a schedule" do
      recipe = recipe_fixture()
      s = schedule_fixture()
      Schedules.toggle_recipe(s.id, recipe.id, MapSet.new())
      ids = Schedules.list_recipe_ids_for_schedule(s.id)
      assert recipe.id in ids
    end
  end

  describe "list_scheduled_recipe_ids/0" do
    test "returns a MapSet of recipe ids that have a schedule" do
      recipe = recipe_fixture()
      s = schedule_fixture()
      Schedules.toggle_recipe(s.id, recipe.id, MapSet.new())
      ids = Schedules.list_scheduled_recipe_ids()
      assert MapSet.member?(ids, recipe.id)
    end
  end

  describe "toggle_recipe/3" do
    test "adds recipe when not present" do
      recipe = recipe_fixture()
      s = schedule_fixture()
      result = Schedules.toggle_recipe(s.id, recipe.id, MapSet.new())
      assert MapSet.member?(result, recipe.id)
    end

    test "removes recipe when already present" do
      recipe = recipe_fixture()
      s = schedule_fixture()
      current = Schedules.toggle_recipe(s.id, recipe.id, MapSet.new())
      result = Schedules.toggle_recipe(s.id, recipe.id, current)
      refute MapSet.member?(result, recipe.id)
    end
  end

  describe "sync_quantum/0" do
    test "runs without error" do
      schedule_fixture(%{enabled: true})
      assert :ok == Schedules.sync_quantum()
    end
  end

  describe "Schedule.days_list/1" do
    test "splits days string into list" do
      s = %Schedule{days: "mon,wed,fri"}
      assert Schedule.days_list(s) == ["mon", "wed", "fri"]
    end

    test "returns empty list for nil days" do
      assert Schedule.days_list(%Schedule{days: nil}) == []
    end
  end

  describe "Schedule.to_cron/1" do
    test "builds cron expression" do
      s = %Schedule{hour: 7, minute: 30, days: "mon,fri"}
      assert Schedule.to_cron(s) == "30 7 * * mon,fri"
    end
  end
end
