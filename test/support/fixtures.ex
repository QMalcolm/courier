defmodule Courier.Fixtures do
  alias Courier.Devices
  alias Courier.Ebooks
  alias Courier.Library
  alias Courier.Repo
  alias Courier.Runs
  alias Courier.Schedules
  alias Courier.Subscriptions

  @valid_source """
  feeds:
    - name: Test Feed
      url: http://127.0.0.1:1/feed
  """

  def recipe_fixture(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    attrs =
      Map.merge(
        %{name: "Recipe #{n}", slug: "recipe-#{n}", source: @valid_source},
        attrs
      )

    {:ok, recipe} = Library.create_recipe(attrs)
    recipe
  end

  def device_fixture(attrs \\ %{}) do
    n = System.unique_integer([:positive])
    attrs = Map.merge(%{name: "Device #{n}", email: "device#{n}@example.com"}, attrs)
    {:ok, device} = Devices.create_device(attrs)
    device
  end

  def subscription_fixture(attrs \\ %{}) do
    recipe = recipe_fixture()
    device = device_fixture()
    attrs = Map.merge(%{recipe_id: recipe.id, device_id: device.id}, attrs)
    {:ok, sub} = Subscriptions.create_subscription(attrs)
    Repo.preload(sub, [:recipe, :device])
  end

  def run_fixture(attrs \\ %{}) do
    recipe = recipe_fixture()
    device = device_fixture()
    attrs = Map.merge(%{recipe_id: recipe.id, device_id: device.id, status: "pending"}, attrs)
    {:ok, run} = Runs.create_run(attrs)
    run
  end

  def schedule_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(%{hour: 7, minute: 30, days: "mon,wed,fri", timezone: "UTC"}, attrs)

    {:ok, schedule} = Schedules.create_schedule(attrs)
    schedule
  end

  def ebook_fixture(attrs \\ %{}) do
    title = Map.get(attrs, :title, "Ebook #{System.unique_integer([:positive])}")
    urls = Map.get(attrs, :urls, ["http://0.0.0.0/article"])
    {:ok, ebook} = Ebooks.create_ebook_with_articles(title, urls)
    ebook
  end
end
