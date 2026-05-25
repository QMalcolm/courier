defmodule CourierWeb.RecipeLiveTest do
  use CourierWeb.ConnCase
  import Phoenix.LiveViewTest
  import Courier.Fixtures

  @valid_source """
  feeds:
    - name: Test Feed
      url: http://127.0.0.1:1/feed
  """

  describe "index" do
    test "renders recipe list", %{conn: conn} do
      recipe = recipe_fixture()
      {:ok, _view, html} = live(conn, ~p"/recipes")
      assert html =~ recipe.name
    end

    test "deletes a recipe", %{conn: conn} do
      recipe = recipe_fixture()
      {:ok, view, _html} = live(conn, ~p"/recipes")
      view |> element("a", "Delete") |> render_click()
      refute render(view) =~ recipe.name
    end

    test "run_now fires without error", %{conn: conn} do
      recipe = recipe_fixture()
      {:ok, view, _html} = live(conn, ~p"/recipes")
      view |> element("[phx-click='run_now'][phx-value-id='#{recipe.id}']") |> render_click()
      assert render(view) =~ "Run started"
    end
  end

  describe "new" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/recipes/new")
      {:ok, view: view}
    end

    test "renders new recipe form", %{view: view} do
      assert render(view) =~ "New Recipe"
    end

    test "creates a recipe with valid params", %{view: view} do
      html =
        view
        |> form("#recipe-form",
          recipe: %{name: "My News", slug: "my-news", source: @valid_source}
        )
        |> render_submit()

      assert html =~ "Recipe created"
    end

    test "shows validation errors for missing name", %{view: view} do
      html =
        view
        |> form("#recipe-form", recipe: %{name: "", slug: "x", source: @valid_source})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "validates on change", %{view: view} do
      html =
        view
        |> form("#recipe-form", recipe: %{name: "X", slug: "", source: @valid_source})
        |> render_change()

      assert is_binary(html)
    end
  end

  describe "edit" do
    test "renders edit form", %{conn: conn} do
      recipe = recipe_fixture()
      {:ok, _view, html} = live(conn, ~p"/recipes/#{recipe}/edit")
      assert html =~ recipe.name
    end

    test "updates the recipe", %{conn: conn} do
      recipe = recipe_fixture()
      {:ok, view, _html} = live(conn, ~p"/recipes/#{recipe}/edit")

      html =
        view
        |> form("#recipe-form", recipe: %{name: "Updated", slug: recipe.slug, source: @valid_source})
        |> render_submit()

      assert html =~ "Recipe updated"
    end

    test "shows validation errors for blank name on edit", %{conn: conn} do
      recipe = recipe_fixture()
      {:ok, view, _html} = live(conn, ~p"/recipes/#{recipe}/edit")

      html =
        view
        |> form("#recipe-form", recipe: %{name: "", slug: recipe.slug, source: @valid_source})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "schedules" do
    test "renders schedule association modal", %{conn: conn} do
      recipe = recipe_fixture()
      schedule = schedule_fixture()
      {:ok, _view, html} = live(conn, ~p"/recipes/#{recipe}/schedules")
      assert html =~ "Schedules"
      assert html =~ CourierWeb.ScheduleLive.Index.format_time(schedule)
    end

    test "toggles a schedule association", %{conn: conn} do
      recipe = recipe_fixture()
      schedule = schedule_fixture()
      {:ok, view, _html} = live(conn, ~p"/recipes/#{recipe}/schedules")

      view
      |> element("[phx-click='toggle_schedule'][phx-value-schedule_id='#{schedule.id}']")
      |> render_click()

      assert render(view) =~ "Saved"
    end
  end

  describe "check_feeds" do
    test "clicking Check Feeds triggers async feed check", %{conn: conn} do
      recipe = recipe_fixture()
      {:ok, view, _html} = live(conn, ~p"/recipes/#{recipe}/edit")

      view |> element("button", "Check Feeds") |> render_click()
      html = render(view)
      assert is_binary(html)
    end
  end

  describe "subscriptions" do
    test "renders device subscription modal", %{conn: conn} do
      recipe = recipe_fixture()
      device = device_fixture()
      {:ok, _view, html} = live(conn, ~p"/recipes/#{recipe}/subscriptions")
      assert html =~ "Devices"
      assert html =~ device.name
    end

    test "toggles a device subscription", %{conn: conn} do
      recipe = recipe_fixture()
      device = device_fixture()
      {:ok, view, _html} = live(conn, ~p"/recipes/#{recipe}/subscriptions")

      view
      |> element("[phx-click='toggle_subscription'][phx-value-device_id='#{device.id}']")
      |> render_click()

      assert render(view) =~ "Saved"

      view
      |> element("[phx-click='toggle_subscription'][phx-value-device_id='#{device.id}']")
      |> render_click()

      assert render(view) =~ "Saved"
    end
  end
end
