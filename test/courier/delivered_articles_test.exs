defmodule Courier.DeliveredArticlesTest do
  use Courier.DataCase, async: false
  import Courier.Fixtures

  alias Courier.DeliveredArticles
  alias Courier.DeliveredArticles.DeliveredArticle

  describe "list_guids_for_recipe/1" do
    test "returns empty MapSet when no articles delivered" do
      recipe = recipe_fixture()
      assert MapSet.new() == DeliveredArticles.list_guids_for_recipe(recipe.id)
    end

    test "returns MapSet of delivered guids for recipe" do
      recipe = recipe_fixture()
      DeliveredArticles.record_articles(recipe.id, ["guid-1", "guid-2"])

      result = DeliveredArticles.list_guids_for_recipe(recipe.id)
      assert MapSet.member?(result, "guid-1")
      assert MapSet.member?(result, "guid-2")
    end

    test "only returns guids for the given recipe" do
      recipe1 = recipe_fixture()
      recipe2 = recipe_fixture()
      DeliveredArticles.record_articles(recipe1.id, ["guid-a"])
      DeliveredArticles.record_articles(recipe2.id, ["guid-b"])

      result = DeliveredArticles.list_guids_for_recipe(recipe1.id)
      assert MapSet.member?(result, "guid-a")
      refute MapSet.member?(result, "guid-b")
    end
  end

  describe "DeliveredArticle.changeset/2" do
    test "validates required fields and builds unique constraint" do
      recipe = recipe_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      valid = %{recipe_id: recipe.id, article_guid: "test-guid", delivered_at: now}
      cs = DeliveredArticle.changeset(%DeliveredArticle{}, valid)
      assert cs.valid?

      invalid = DeliveredArticle.changeset(%DeliveredArticle{}, %{})
      refute invalid.valid?
    end
  end

  describe "record_articles/2" do
    test "returns {0, nil} for empty guid list" do
      recipe = recipe_fixture()
      assert {0, nil} = DeliveredArticles.record_articles(recipe.id, [])
    end

    test "inserts articles and returns count" do
      recipe = recipe_fixture()
      {count, _} = DeliveredArticles.record_articles(recipe.id, ["a", "b", "c"])
      assert count == 3
    end

    test "ignores duplicate guids on conflict" do
      recipe = recipe_fixture()
      DeliveredArticles.record_articles(recipe.id, ["dup"])
      {count, _} = DeliveredArticles.record_articles(recipe.id, ["dup", "new"])
      assert count == 1
    end
  end
end
