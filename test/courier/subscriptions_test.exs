defmodule Courier.SubscriptionsTest do
  use Courier.DataCase, async: false
  import Courier.Fixtures

  alias Courier.Subscriptions
  alias Courier.Subscriptions.Subscription

  describe "list_subscriptions_for_device/1" do
    test "returns subscriptions for a device" do
      sub = subscription_fixture()
      results = Subscriptions.list_subscriptions_for_device(sub.device_id)
      assert length(results) == 1
      assert hd(results).recipe != nil
    end
  end

  describe "list_subscriptions_for_recipe/1" do
    test "returns subscriptions for a recipe" do
      sub = subscription_fixture()
      results = Subscriptions.list_subscriptions_for_recipe(sub.recipe_id)
      assert length(results) == 1
      assert hd(results).device != nil
    end
  end

  describe "list_subscriptions/0" do
    test "returns all subscriptions with recipe and device preloaded" do
      subscription_fixture()
      results = Subscriptions.list_subscriptions()
      assert length(results) >= 1
      assert hd(results).recipe != nil
      assert hd(results).device != nil
    end
  end

  describe "list_enabled_subscriptions/0" do
    test "only returns enabled subscriptions" do
      sub = subscription_fixture()
      Subscriptions.update_subscription(sub, %{enabled: false})
      subscription_fixture()

      enabled = Subscriptions.list_enabled_subscriptions()
      assert Enum.all?(enabled, & &1.enabled)
    end
  end

  describe "list_enabled_subscriptions_for_recipe/1" do
    test "returns only enabled subscriptions for the recipe" do
      sub = subscription_fixture()
      Subscriptions.update_subscription(sub, %{enabled: false})
      active_sub = subscription_fixture()

      results = Subscriptions.list_enabled_subscriptions_for_recipe(active_sub.recipe_id)
      assert length(results) == 1
    end
  end

  describe "list_enabled_subscriptions_for_recipes/1" do
    test "returns enabled subscriptions for multiple recipes" do
      s1 = subscription_fixture()
      s2 = subscription_fixture()
      ids = [s1.recipe_id, s2.recipe_id]
      results = Subscriptions.list_enabled_subscriptions_for_recipes(ids)
      assert length(results) == 2
    end
  end

  describe "get_subscription_by_device_and_recipe/2" do
    test "returns subscription when it exists" do
      sub = subscription_fixture()
      found = Subscriptions.get_subscription_by_device_and_recipe(sub.device_id, sub.recipe_id)
      assert found.id == sub.id
    end

    test "returns nil when it does not exist" do
      assert nil == Subscriptions.get_subscription_by_device_and_recipe(0, 0)
    end
  end

  describe "get_subscription!/1" do
    test "returns subscription with preloads" do
      sub = subscription_fixture()
      result = Subscriptions.get_subscription!(sub.id)
      assert result.recipe != nil
      assert result.device != nil
    end
  end

  describe "create_subscription/1" do
    test "creates a subscription with valid attrs" do
      recipe = recipe_fixture()
      device = device_fixture()
      assert {:ok, sub} = Subscriptions.create_subscription(%{recipe_id: recipe.id, device_id: device.id})
      assert sub.enabled == true
    end

    test "enforces uniqueness of recipe+device pair" do
      sub = subscription_fixture()
      assert {:error, cs} =
               Subscriptions.create_subscription(%{recipe_id: sub.recipe_id, device_id: sub.device_id})
      assert errors_on(cs).recipe_id != []
    end

    test "returns validation error when called with no arguments" do
      assert {:error, cs} = Subscriptions.create_subscription()
      assert errors_on(cs).recipe_id != []
    end
  end

  describe "update_subscription/2" do
    test "updates enabled flag" do
      sub = subscription_fixture()
      assert {:ok, updated} = Subscriptions.update_subscription(sub, %{enabled: false})
      assert updated.enabled == false
    end
  end

  describe "delete_subscription/1" do
    test "deletes the subscription" do
      sub = subscription_fixture()
      assert {:ok, _} = Subscriptions.delete_subscription(sub)
      assert nil == Subscriptions.get_subscription_by_device_and_recipe(sub.device_id, sub.recipe_id)
    end
  end

  describe "change_subscription/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = Subscriptions.change_subscription(%Subscription{})
    end
  end
end
