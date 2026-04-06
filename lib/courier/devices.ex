defmodule Courier.Devices do
  import Ecto.Query
  alias Courier.Repo
  alias Courier.Devices.Device

  def list_devices do
    Repo.all(from d in Device, order_by: d.name)
  end

  def get_device!(id), do: Repo.get!(Device, id)

  def create_device(attrs \\ %{}) do
    %Device{}
    |> Device.changeset(attrs)
    |> Repo.insert()
  end

  def update_device(%Device{} = device, attrs) do
    device
    |> Device.changeset(attrs)
    |> Repo.update()
  end

  def delete_device(%Device{} = device), do: Repo.delete(device)

  def change_device(%Device{} = device, attrs \\ %{}) do
    Device.changeset(device, attrs)
  end
end
