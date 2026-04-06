defmodule Courier.Subscriptions.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  schema "subscriptions" do
    field :enabled, :boolean, default: true

    belongs_to :recipe, Courier.Library.Recipe
    belongs_to :device, Courier.Devices.Device

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:enabled, :recipe_id, :device_id])
    |> validate_required([:recipe_id, :device_id])
    |> unique_constraint([:recipe_id, :device_id])
  end
end
