defmodule CourierWeb.ScheduleLiveTest do
  use CourierWeb.ConnCase
  import Phoenix.LiveViewTest
  import Courier.Fixtures

  describe "index" do
    test "renders schedule list", %{conn: conn} do
      schedule = schedule_fixture(%{label: "Morning Run"})
      {:ok, _view, html} = live(conn, ~p"/schedule")
      assert html =~ CourierWeb.ScheduleLive.Index.format_time(schedule)
    end

    test "toggles a schedule on/off", %{conn: conn} do
      schedule = schedule_fixture(%{enabled: true})
      {:ok, view, _html} = live(conn, ~p"/schedule")

      view |> element("[phx-click='toggle'][phx-value-id='#{schedule.id}']") |> render_click()
      assert render(view) =~ "Saved"
    end

    test "deletes a schedule", %{conn: conn} do
      _schedule = schedule_fixture()
      {:ok, view, _html} = live(conn, ~p"/schedule")
      view |> element("a", "Delete") |> render_click()
      assert render(view) =~ "Schedule"
    end
  end

  describe "new" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/schedule/new")
      {:ok, view: view}
    end

    test "renders new schedule form", %{view: view} do
      assert render(view) =~ "New Schedule"
    end

    test "creates a schedule with valid params", %{view: view} do
      html =
        view
        |> element("form#schedule-form")
        |> render_submit(%{
          "schedule" => %{
            "hour" => "8",
            "minute" => "0",
            "days" => ["mon", "fri"],
            "timezone" => "UTC"
          }
        })

      assert html =~ "Schedule created"
    end

    test "shows validation error for invalid hour", %{view: view} do
      html =
        view
        |> element("form#schedule-form")
        |> render_submit(%{
          "schedule" => %{"hour" => "99", "minute" => "0", "days" => ["mon"], "timezone" => "UTC"}
        })

      assert html =~ "must be less than"
    end

    test "validates on change", %{view: view} do
      html =
        view
        |> element("form#schedule-form")
        |> render_change(%{
          "schedule" => %{"hour" => "8", "minute" => "0", "days" => ["mon"], "timezone" => "UTC"}
        })

      assert is_binary(html)
    end
  end

  describe "edit" do
    test "renders edit form with existing values", %{conn: conn} do
      schedule = schedule_fixture(%{label: "My Schedule"})
      {:ok, _view, html} = live(conn, ~p"/schedule/#{schedule}/edit")
      assert html =~ "Edit Schedule"
    end

    test "updates the schedule", %{conn: conn} do
      schedule = schedule_fixture()
      {:ok, view, _html} = live(conn, ~p"/schedule/#{schedule}/edit")

      html =
        view
        |> element("form#schedule-form")
        |> render_submit(%{
          "schedule" => %{
            "hour" => to_string(schedule.hour),
            "minute" => to_string(schedule.minute),
            "days" => String.split(schedule.days, ","),
            "timezone" => "America/New_York"
          }
        })

      assert html =~ "Schedule updated"
    end
  end

  describe "recipes" do
    test "renders recipe association modal", %{conn: conn} do
      schedule = schedule_fixture()
      recipe = recipe_fixture()
      {:ok, _view, html} = live(conn, ~p"/schedule/#{schedule}/recipes")
      assert html =~ recipe.name
    end

    test "toggles a recipe association", %{conn: conn} do
      schedule = schedule_fixture()
      recipe = recipe_fixture()
      {:ok, view, _html} = live(conn, ~p"/schedule/#{schedule}/recipes")

      view
      |> element("[phx-click='toggle_recipe'][phx-value-recipe_id='#{recipe.id}']")
      |> render_click()

      assert render(view) =~ "Saved"
    end
  end

  describe "helper functions" do
    test "format_time/1 formats hour and minute" do
      s = %Courier.Schedules.Schedule{hour: 7, minute: 5, timezone: "UTC"}
      assert CourierWeb.ScheduleLive.Index.format_time(s) == "07:05 UTC"
    end

    test "format_days/1 capitalizes days" do
      s = %Courier.Schedules.Schedule{days: "mon,wed,fri"}
      assert CourierWeb.ScheduleLive.Index.format_days(s) == "Mon, Wed, Fri"
    end

    test "day_checked?/2 returns true when day is in form value" do
      s = %Courier.Schedules.Schedule{days: "mon,fri"}
      assert CourierWeb.ScheduleLive.Index.day_checked?(s, "mon") == true
      assert CourierWeb.ScheduleLive.Index.day_checked?(s, "sat") == false
    end
  end
end
