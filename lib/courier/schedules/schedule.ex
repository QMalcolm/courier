defmodule Courier.Schedules.Schedule do
  use Ecto.Schema
  import Ecto.Changeset

  @days ~w(mon tue wed thu fri sat sun)

  schema "schedules" do
    field :label, :string
    field :hour, :integer
    field :minute, :integer
    field :days, :string
    field :timezone, :string, default: "UTC"
    field :enabled, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  def changeset(schedule, attrs) do
    attrs = normalize_days(attrs)

    schedule
    |> cast(attrs, [:label, :hour, :minute, :days, :timezone, :enabled])
    |> validate_required([:hour, :minute, :days, :timezone])
    |> validate_number(:hour, greater_than_or_equal_to: 0, less_than: 24)
    |> validate_number(:minute, greater_than_or_equal_to: 0, less_than: 60)
    |> validate_days()
  end

  # Convert checkbox list ["mon", "fri"] → "mon,fri" before casting
  defp normalize_days(%{"days" => days} = attrs) when is_list(days) do
    valid = Enum.filter(days, &(&1 in @days))
    Map.put(attrs, "days", Enum.join(valid, ","))
  end

  defp normalize_days(attrs), do: attrs

  defp validate_days(changeset) do
    case get_field(changeset, :days) do
      nil -> add_error(changeset, :days, "must select at least one day")
      "" -> add_error(changeset, :days, "must select at least one day")
      _ -> changeset
    end
  end

  @doc "Returns the days field as a list, e.g. [\"mon\", \"fri\"]"
  def days_list(%__MODULE__{days: days}) when is_binary(days) do
    String.split(days, ",", trim: true)
  end

  def days_list(_), do: []

  @doc "Builds a cron expression string for this schedule, e.g. \"30 7 * * mon,fri\""
  def to_cron(%__MODULE__{hour: hour, minute: minute, days: days}) do
    "#{minute} #{hour} * * #{days}"
  end
end
