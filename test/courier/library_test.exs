defmodule Courier.LibraryTest do
  use Courier.DataCase, async: false
  import Courier.Fixtures

  alias Courier.Library
  alias Courier.Library.Recipe

  @valid_source """
  feeds:
    - name: Test
      url: http://127.0.0.1:1/feed
  """

  describe "list_recipes/0" do
    test "returns recipes ordered by name" do
      recipe_fixture(%{name: "Zebra", slug: "z"})
      recipe_fixture(%{name: "Alpha", slug: "a"})
      names = Library.list_recipes() |> Enum.map(& &1.name)
      assert names == Enum.sort(names)
    end
  end

  describe "get_recipe!/1" do
    test "returns the recipe" do
      r = recipe_fixture()
      assert Library.get_recipe!(r.id).id == r.id
    end

    test "raises on missing id" do
      assert_raise Ecto.NoResultsError, fn -> Library.get_recipe!(0) end
    end
  end

  describe "get_recipe_by_slug!/1" do
    test "returns recipe by slug" do
      r = recipe_fixture(%{slug: "my-slug"})
      assert Library.get_recipe_by_slug!("my-slug").id == r.id
    end
  end

  describe "create_recipe/1" do
    test "creates with valid attrs" do
      assert {:ok, %Recipe{name: "News"}} =
               Library.create_recipe(%{name: "News", slug: "news", source: @valid_source})
    end

    test "returns error for missing name" do
      assert {:error, cs} = Library.create_recipe(%{slug: "x", source: @valid_source})
      assert "can't be blank" in errors_on(cs).name
    end

    test "returns error for duplicate slug" do
      recipe_fixture(%{slug: "dup"})

      assert {:error, cs} =
               Library.create_recipe(%{name: "Y", slug: "dup", source: @valid_source})

      assert "has already been taken" in errors_on(cs).slug
    end

    test "returns error for invalid YAML" do
      assert {:error, cs} = Library.create_recipe(%{name: "X", slug: "x", source: "{"})
      assert errors_on(cs).source != []
    end

    test "returns error for YAML without feeds" do
      bad_source = "description: no feeds here\n"
      assert {:error, cs} = Library.create_recipe(%{name: "X", slug: "x", source: bad_source})
      assert errors_on(cs).source != []
    end

    test "returns error for feed missing url" do
      bad_source = "feeds:\n  - name: Test\n"
      assert {:error, cs} = Library.create_recipe(%{name: "X", slug: "x", source: bad_source})
      assert errors_on(cs).source != []
    end

    test "returns error for oldest_article <= 0" do
      assert {:error, cs} =
               Library.create_recipe(%{
                 name: "X",
                 slug: "x",
                 source: @valid_source,
                 oldest_article: 0
               })

      assert errors_on(cs).oldest_article != []
    end
  end

  describe "update_recipe/2" do
    test "updates the recipe" do
      r = recipe_fixture()
      assert {:ok, updated} = Library.update_recipe(r, %{name: "Updated"})
      assert updated.name == "Updated"
    end
  end

  describe "delete_recipe/1" do
    test "deletes the recipe" do
      r = recipe_fixture()
      assert {:ok, _} = Library.delete_recipe(r)
      assert_raise Ecto.NoResultsError, fn -> Library.get_recipe!(r.id) end
    end
  end

  describe "change_recipe/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = Library.change_recipe(%Recipe{})
    end
  end

  describe "Recipe.to_python/3" do
    test "generates valid Python recipe string" do
      r = recipe_fixture()
      python = Recipe.to_python(r, "run-1", "http://localhost:4000")
      assert python =~ "class GeneratedRecipe"
      assert python =~ "proxy/feed"
      assert python =~ "run_id=run-1"
    end

    test "escapes single quotes in recipe name" do
      r = recipe_fixture(%{name: "O'Brien's News", slug: "obriens"})
      python = Recipe.to_python(r, "1", "http://localhost:4000")
      assert python =~ "\\'Brien"
    end

    test "handles optional YAML fields" do
      source = """
      feeds:
        - name: F
          url: http://example.com
      language: fr
      auto_cleanup: false
      use_embedded_content: true
      """

      r = recipe_fixture(%{source: source, slug: "opts"})
      python = Recipe.to_python(r, "1", "http://localhost:4000")
      assert python =~ "language              = 'fr'"
      assert python =~ "auto_cleanup          = False"
      assert python =~ "use_embedded_content  = True"
    end
  end

  describe "check_feeds_detailed/1" do
    test "returns empty list for invalid YAML" do
      assert [] == Library.check_feeds_detailed(%{"source" => "{{not yaml"})
    end

    test "returns empty list for missing source" do
      assert [] == Library.check_feeds_detailed(%{})
    end

    test "returns empty list for YAML without feeds" do
      assert [] == Library.check_feeds_detailed(%{"source" => "description: hi\n"})
    end

    test "returns error result for unreachable feed" do
      source = "feeds:\n  - name: Test\n    url: http://127.0.0.1:1/feed\n"
      [result] = Library.check_feeds_detailed(%{"source" => source})
      assert result.name == "Test"
      assert result.ok == false
    end

    test "returns ok result with article count for reachable feed" do
      bypass = Bypass.open()

      multi_item_feed = """
      <?xml version="1.0"?>
      <rss version="2.0"><channel>
        <item><guid>g1</guid><title>A</title></item>
        <item><guid>g2</guid><title>B</title></item>
        <item><guid>g3</guid><title>C</title></item>
      </channel></rss>
      """

      single_item_feed = """
      <?xml version="1.0"?>
      <rss version="2.0"><channel>
        <item><guid>only</guid><title>Solo</title></item>
      </channel></rss>
      """

      Bypass.expect(bypass, fn conn ->
        body =
          if conn.request_path == "/single", do: single_item_feed, else: multi_item_feed

        conn
        |> Plug.Conn.put_resp_content_type("application/rss+xml")
        |> Plug.Conn.send_resp(200, body)
      end)

      source = """
      feeds:
        - name: Many
          url: http://localhost:#{bypass.port}/many
        - name: One
          url: http://localhost:#{bypass.port}/single
      """

      [many, one] = Library.check_feeds_detailed(%{"source" => source})
      assert many.ok == true
      assert many.detail =~ "articles found"
      assert one.ok == true
      assert one.detail == "1 article found"
    end
  end
end
