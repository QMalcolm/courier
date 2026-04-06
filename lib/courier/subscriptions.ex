defmodule Courier.Subscriptions do
  import Ecto.Query
  alias Courier.Repo
  alias Courier.Subscriptions.Subscription

  def list_subscriptions do
    Repo.all(
      from s in Subscription,
        join: r in assoc(s, :recipe),
        join: d in assoc(s, :device),
        order_by: [r.name, d.name],
        preload: [recipe: r, device: d]
    )
  end

  def list_enabled_subscriptions do
    Repo.all(
      from s in Subscription,
        where: s.enabled == true,
        preload: [:recipe, :device]
    )
  end

  def get_subscription!(id), do: Repo.get!(Subscription, id) |> Repo.preload([:recipe, :device])

  def create_subscription(attrs \\ %{}) do
    %Subscription{}
    |> Subscription.changeset(attrs)
    |> Repo.insert()
  end

  def update_subscription(%Subscription{} = subscription, attrs) do
    subscription
    |> Subscription.changeset(attrs)
    |> Repo.update()
  end

  def delete_subscription(%Subscription{} = subscription), do: Repo.delete(subscription)

  def change_subscription(%Subscription{} = subscription, attrs \\ %{}) do
    Subscription.changeset(subscription, attrs)
  end
end
