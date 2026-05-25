defmodule Courier.RunnerTest do
  use Courier.DataCase, async: false
  import Courier.Fixtures

  alias Courier.DeliveredArticles
  alias Courier.Repo
  alias Courier.Runner
  alias Courier.Runs
  alias Courier.Subscriptions

  setup do
    Phoenix.PubSub.subscribe(Courier.PubSub, "runs")
    :ok
  end

  describe "run_for_schedule/1" do
    test "completes without error when schedule has no recipes" do
      schedule = schedule_fixture()
      assert :ok == Runner.run_for_schedule(schedule.id)
    end
  end

  describe "run_recipe/1" do
    test "completes without error when recipe has no subscriptions" do
      recipe = recipe_fixture()
      assert :ok == Runner.run_recipe(recipe.id)
    end
  end

  describe "run/1" do
    test "starts async delivery task and creates a run record" do
      subscription = subscription_fixture()
      assert {:ok, _pid} = Runner.run(subscription)

      assert_receive {:run_updated, %{status: "running"}}, 3_000
      assert_receive {:run_updated, %{status: final_status}}, 15_000
      assert final_status in ["failure", "skipped"]

      runs = Runs.list_runs()
      assert length(runs) == 1
      assert hd(runs).status == final_status
    end

    test "skips delivery when all articles already delivered" do
      bypass = Bypass.open()

      rss_feed = """
      <?xml version="1.0"?>
      <rss version="2.0"><channel>
        <item><guid>old-article-1</guid><title>Old</title></item>
        <item><guid>old-article-2</guid><title>Also Old</title></item>
      </channel></rss>
      """

      Bypass.expect(bypass, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/rss+xml")
        |> Plug.Conn.send_resp(200, rss_feed)
      end)

      source = "feeds:\n  - name: Test\n    url: http://localhost:#{bypass.port}/feed\n"
      recipe = recipe_fixture(%{source: source})
      device = device_fixture()

      {:ok, sub} =
        Subscriptions.create_subscription(%{recipe_id: recipe.id, device_id: device.id})

      sub = Repo.preload(sub, [:recipe, :device])

      DeliveredArticles.record_articles(recipe.id, ["old-article-1", "old-article-2"])

      assert {:ok, _pid} = Runner.run(sub)
      assert_receive {:run_updated, %{status: "running"}}, 3_000
      assert_receive {:run_updated, %{status: "skipped"}}, 15_000
    end
  end
end
