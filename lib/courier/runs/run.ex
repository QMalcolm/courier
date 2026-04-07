defmodule Courier.Runs.Run do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending running success failure skipped)

  schema "runs" do
    field :status, :string, default: "pending"
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :log_output, :string

    belongs_to :recipe, Courier.Library.Recipe
    belongs_to :device, Courier.Devices.Device

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(run, attrs) do
    run
    |> cast(attrs, [:started_at, :finished_at, :status, :log_output, :recipe_id, :device_id])
    |> validate_required([:recipe_id, :device_id, :status])
    |> validate_inclusion(:status, @statuses)
  end
end
