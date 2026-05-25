defmodule CourierWeb.RunLiveTest do
  use CourierWeb.ConnCase
  import Phoenix.LiveViewTest
  import Courier.Fixtures

  alias CourierWeb.RunLive.Index

  describe "index" do
    test "renders run list", %{conn: conn} do
      run = run_fixture(%{status: "success"})
      {:ok, _view, html} = live(conn, ~p"/logs")
      assert html =~ run.status
    end

    test "updates when run_updated PubSub message received", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/logs")

      run = run_fixture(%{status: "running"})
      Phoenix.PubSub.broadcast(Courier.PubSub, "runs", {:run_updated, run})

      html = render(view)
      assert html =~ "running"
    end
  end

  describe "status_class/1" do
    test "success is green" do
      assert Index.status_class("success") =~ "green"
    end

    test "failure is red" do
      assert Index.status_class("failure") =~ "red"
    end

    test "running is blue" do
      assert Index.status_class("running") =~ "blue"
    end

    test "skipped is amber" do
      assert Index.status_class("skipped") =~ "amber"
    end

    test "unknown falls back to zinc" do
      assert Index.status_class("pending") =~ "zinc"
    end
  end

  describe "article_count_display/1" do
    test "singular form for 1 article" do
      assert Index.article_count_display(%{article_count: 1}) == "1 article"
    end

    test "plural form for multiple articles" do
      assert Index.article_count_display(%{article_count: 5}) == "5 articles"
    end

    test "dash for nil count" do
      assert Index.article_count_display(%{article_count: nil}) == "—"
    end
  end

  describe "duration/1" do
    test "dash when not started" do
      assert Index.duration(%{started_at: nil}) == "—"
    end

    test "running when no finished_at" do
      assert Index.duration(%{started_at: ~U[2024-01-01 10:00:00Z], finished_at: nil}) ==
               "running…"
    end

    test "seconds duration" do
      assert Index.duration(%{
               started_at: ~U[2024-01-01 10:00:00Z],
               finished_at: ~U[2024-01-01 10:00:07Z]
             }) == "7s"
    end
  end
end
