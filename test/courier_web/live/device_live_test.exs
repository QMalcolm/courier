defmodule CourierWeb.DeviceLiveTest do
  use CourierWeb.ConnCase
  import Phoenix.LiveViewTest
  import Courier.Fixtures

  describe "index" do
    test "renders device list", %{conn: conn} do
      device = device_fixture()
      {:ok, _view, html} = live(conn, ~p"/devices")
      assert html =~ device.name
      assert html =~ device.email
    end

    test "deletes a device", %{conn: conn} do
      device = device_fixture()
      {:ok, view, _html} = live(conn, ~p"/devices")
      view |> element("a", "Delete") |> render_click()
      refute render(view) =~ device.name
    end
  end

  describe "new" do
    test "renders new device form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/devices/new")
      assert html =~ "New Device"
    end

    test "creates a device with valid params", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/devices/new")

      html =
        view
        |> form("#device-form", device: %{name: "My Kindle", email: "kindle@example.com"})
        |> render_submit()

      assert html =~ "Device created"
    end

    test "shows validation errors with invalid params", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/devices/new")

      html =
        view
        |> form("#device-form", device: %{name: "", email: "bad"})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "validates on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/devices/new")

      html =
        view
        |> form("#device-form", device: %{name: "", email: ""})
        |> render_change()

      assert is_binary(html)
    end
  end

  describe "edit" do
    test "renders edit form with existing values", %{conn: conn} do
      device = device_fixture()
      {:ok, _view, html} = live(conn, ~p"/devices/#{device}/edit")
      assert html =~ device.name
    end

    test "updates the device", %{conn: conn} do
      device = device_fixture()
      {:ok, view, _html} = live(conn, ~p"/devices/#{device}/edit")

      html =
        view
        |> form("#device-form", device: %{name: "Updated Name", email: device.email})
        |> render_submit()

      assert html =~ "Device updated"
    end

    test "shows validation error on bad update", %{conn: conn} do
      device = device_fixture()
      {:ok, view, _html} = live(conn, ~p"/devices/#{device}/edit")

      html =
        view
        |> form("#device-form", device: %{email: "not-an-email"})
        |> render_submit()

      assert html =~ "invalid"
    end
  end

  describe "subscriptions" do
    test "renders subscription modal with recipes", %{conn: conn} do
      device = device_fixture()
      recipe = recipe_fixture()
      {:ok, _view, html} = live(conn, ~p"/devices/#{device}/subscriptions")
      assert html =~ "Subscriptions"
      assert html =~ recipe.name
    end

    test "toggling subscription adds it", %{conn: conn} do
      device = device_fixture()
      recipe = recipe_fixture()
      {:ok, view, _html} = live(conn, ~p"/devices/#{device}/subscriptions")

      view
      |> element("[phx-click='toggle_subscription'][phx-value-recipe_id='#{recipe.id}']")
      |> render_click()

      assert render(view) =~ "Saved"
    end

    test "toggling subscription twice removes it", %{conn: conn} do
      device = device_fixture()
      recipe = recipe_fixture()
      {:ok, view, _html} = live(conn, ~p"/devices/#{device}/subscriptions")

      view
      |> element("[phx-click='toggle_subscription'][phx-value-recipe_id='#{recipe.id}']")
      |> render_click()

      view
      |> element("[phx-click='toggle_subscription'][phx-value-recipe_id='#{recipe.id}']")
      |> render_click()

      assert render(view) =~ "Saved"
    end
  end
end
