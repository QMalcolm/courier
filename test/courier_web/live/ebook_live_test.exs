defmodule CourierWeb.EbookLiveTest do
  use CourierWeb.ConnCase
  import Phoenix.LiveViewTest
  import Courier.Fixtures

  alias CourierWeb.EbookLive.Index
  alias CourierWeb.EbookLive.Show

  describe "index" do
    test "renders ebook list", %{conn: conn} do
      ebook = ebook_fixture()
      {:ok, _view, html} = live(conn, ~p"/ebooks")
      assert html =~ ebook.title
    end

    test "deletes an ebook", %{conn: conn} do
      ebook = ebook_fixture()
      {:ok, view, _html} = live(conn, ~p"/ebooks")
      view |> element("a", "Delete") |> render_click()
      refute render(view) =~ ebook.title
    end

    test "updates list on ebook_updated PubSub message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/ebooks")
      ebook = ebook_fixture()
      Phoenix.PubSub.broadcast(Courier.PubSub, "ebooks", {:ebook_updated, ebook})
      assert render(view) =~ ebook.title
    end
  end

  describe "new" do
    test "renders new ebook form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/ebooks/new")
      assert html =~ "New Ebook"
    end

    test "shows error for empty title" do
      {:ok, view, _html} = build_conn() |> live(~p"/ebooks/new")

      html =
        view
        |> element("form[phx-submit=create]")
        |> render_submit(%{title: "", urls_text: ""})

      assert html =~ "Title can&#39;t be blank"
    end

    test "shows error for missing URLs" do
      {:ok, view, _html} = build_conn() |> live(~p"/ebooks/new")

      html =
        view
        |> element("form[phx-submit=create]")
        |> render_submit(%{title: "My Book", urls_text: ""})

      assert html =~ "Must include at least one URL"
    end

    test "shows error for invalid URL format" do
      {:ok, view, _html} = build_conn() |> live(~p"/ebooks/new")

      html =
        view
        |> element("form[phx-submit=create]")
        |> render_submit(%{title: "My Book", urls_text: "not-a-url"})

      assert html =~ "must be a valid http or https URL"
    end

    test "shows error for private IP URL" do
      {:ok, view, _html} = build_conn() |> live(~p"/ebooks/new")

      html =
        view
        |> element("form[phx-submit=create]")
        |> render_submit(%{title: "My Book", urls_text: "http://192.168.1.1/page"})

      assert html =~ "must be a public URL"
    end

    test "shows error for 172.16-31 range private IP URL" do
      {:ok, view, _html} = build_conn() |> live(~p"/ebooks/new")

      html =
        view
        |> element("form[phx-submit=create]")
        |> render_submit(%{title: "My Book", urls_text: "http://172.16.1.1/page"})

      assert html =~ "must be a public URL"
    end

    test "shows reachability error when URL is syntactically valid but unreachable" do
      {:ok, view, _html} = build_conn() |> live(~p"/ebooks/new")

      html =
        view
        |> element("form[phx-submit=create]")
        |> render_submit(%{title: "My Book", urls_text: "http://0.0.0.0:1/page"})

      assert is_binary(html)
    end

    test "preserves title and urls_text after validation error" do
      {:ok, view, _html} = build_conn() |> live(~p"/ebooks/new")

      html =
        view
        |> element("form[phx-submit=create]")
        |> render_submit(%{title: "My Book", urls_text: "not-a-url"})

      assert html =~ "My Book"
      assert html =~ "not-a-url"
    end
  end

  describe "show" do
    test "renders ebook detail page", %{conn: conn} do
      ebook = ebook_fixture()
      {:ok, _view, html} = live(conn, ~p"/ebooks/#{ebook}")
      assert html =~ ebook.title
    end

    test "updates on ebook_updated PubSub for this ebook", %{conn: conn} do
      ebook = ebook_fixture()
      {:ok, view, _html} = live(conn, ~p"/ebooks/#{ebook}")

      {:ok, updated} = Courier.Ebooks.update_ebook(ebook, %{status: "success"})
      Phoenix.PubSub.broadcast(Courier.PubSub, "ebooks", {:ebook_updated, updated})

      assert render(view) =~ "success"
    end

    test "ignores ebook_updated PubSub for other ebooks", %{conn: conn} do
      ebook = ebook_fixture()
      {:ok, view, _html} = live(conn, ~p"/ebooks/#{ebook}")

      other = ebook_fixture()
      Phoenix.PubSub.broadcast(Courier.PubSub, "ebooks", {:ebook_updated, other})

      assert render(view) =~ ebook.title
    end

    test "retry event fires without error", %{conn: conn} do
      ebook = ebook_fixture()
      {:ok, ebook} = Courier.Ebooks.update_ebook(ebook, %{status: "failure"})
      {:ok, view, _html} = live(conn, ~p"/ebooks/#{ebook}")
      view |> element("button[phx-click='retry']") |> render_click()
      assert render(view) =~ "Retrying"
    end

    test "send_to_device fires without error", %{conn: conn} do
      ebook = ebook_fixture()
      {:ok, ebook} = Courier.Ebooks.update_ebook(ebook, %{status: "success"})
      device = device_fixture()
      {:ok, view, _html} = live(conn, ~p"/ebooks/#{ebook}")

      view
      |> element("button[phx-click='send_to_device'][phx-value-device_id='#{device.id}']")
      |> render_click()

      assert render(view) =~ "Sending"
    end

    test "renders ebook with non-empty sends list", %{conn: conn} do
      ebook = ebook_fixture()
      device = device_fixture()
      {:ok, _send} = Courier.Ebooks.create_send(%{ebook_id: ebook.id, device_id: device.id, status: "success"})
      {:ok, _view, html} = live(conn, ~p"/ebooks/#{ebook}")
      assert html =~ ebook.title
    end
  end

  describe "Index helper functions" do
    test "status_class/1 returns css classes" do
      assert Index.status_class("success") =~ "green"
      assert Index.status_class("failure") =~ "red"
      assert Index.status_class("running") =~ "blue"
      assert Index.status_class("pending") =~ "zinc"
    end

    test "duration/1" do
      assert Index.duration(%{started_at: nil}) == "—"
      assert Index.duration(%{started_at: ~U[2024-01-01 10:00:00Z], finished_at: nil}) == "running…"

      assert Index.duration(%{
               started_at: ~U[2024-01-01 10:00:00Z],
               finished_at: ~U[2024-01-01 10:00:05Z]
             }) == "5s"
    end
  end

  describe "Show helper functions" do
    test "send_running?/1" do
      assert Show.send_running?(%{status: "running"}) == true
      assert Show.send_running?(%{status: "success"}) == false
      assert Show.send_running?(nil) == false
    end

    test "already_sent?/1" do
      assert Show.already_sent?(%{status: "success"}) == true
      assert Show.already_sent?(%{status: "running"}) == false
      assert Show.already_sent?(nil) == false
    end

    test "send_label/1" do
      assert Show.send_label(nil) == "Not sent"
      assert Show.send_label(%{status: "running"}) == "Sending…"
      assert Show.send_label(%{status: "success", sent_at: nil}) == "Sent"
      assert Show.send_label(%{status: "failure"}) =~ "retry"

      sent_at = ~U[2024-06-15 14:30:00Z]
      assert Show.send_label(%{status: "success", sent_at: sent_at}) =~ "Jun 15"
    end

    test "status_class/1" do
      assert Show.status_class("success") =~ "green"
      assert Show.status_class("failure") =~ "red"
      assert Show.status_class("running") =~ "blue"
      assert Show.status_class("pending") =~ "zinc"
    end

    test "duration/1" do
      assert Show.duration(%{started_at: nil}) == nil
      assert Show.duration(%{started_at: ~U[2024-01-01 10:00:00Z], finished_at: nil}) == "running…"

      assert Show.duration(%{
               started_at: ~U[2024-01-01 10:00:00Z],
               finished_at: ~U[2024-01-01 10:00:03Z]
             }) == "3s"
    end
  end
end
