defmodule Courier.DevicesTest do
  use Courier.DataCase, async: false
  import Courier.Fixtures

  alias Courier.Devices
  alias Courier.Devices.Device

  describe "list_devices/0" do
    test "returns all devices ordered by name" do
      d1 = device_fixture(%{name: "Zebra"})
      d2 = device_fixture(%{name: "Alpha"})
      ids = Devices.list_devices() |> Enum.map(& &1.id)
      assert Enum.find_index(ids, &(&1 == d2.id)) < Enum.find_index(ids, &(&1 == d1.id))
    end
  end

  describe "get_device!/1" do
    test "returns the device" do
      device = device_fixture()
      assert Devices.get_device!(device.id).id == device.id
    end

    test "raises on missing id" do
      assert_raise Ecto.NoResultsError, fn -> Devices.get_device!(0) end
    end
  end

  describe "create_device/1" do
    test "creates with valid attrs" do
      assert {:ok, %Device{name: "Kindle", email: "kindle@test.com"}} =
               Devices.create_device(%{name: "Kindle", email: "kindle@test.com"})
    end

    test "returns validation error when called with no arguments" do
      assert {:error, cs} = Devices.create_device()
      assert errors_on(cs).name != []
    end

    test "returns error for missing name" do
      assert {:error, cs} = Devices.create_device(%{email: "x@x.com"})
      assert "can't be blank" in errors_on(cs).name
    end

    test "returns error for missing email" do
      assert {:error, cs} = Devices.create_device(%{name: "X"})
      assert "can't be blank" in errors_on(cs).email
    end

    test "returns error for invalid email format" do
      assert {:error, cs} = Devices.create_device(%{name: "X", email: "notanemail"})
      assert errors_on(cs).email != []
    end

    test "returns error for duplicate email" do
      device_fixture(%{email: "dup@test.com"})
      assert {:error, cs} = Devices.create_device(%{name: "Y", email: "dup@test.com"})
      assert "has already been taken" in errors_on(cs).email
    end
  end

  describe "update_device/2" do
    test "updates the device" do
      device = device_fixture()
      assert {:ok, updated} = Devices.update_device(device, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "returns error on invalid attrs" do
      device = device_fixture()
      assert {:error, _} = Devices.update_device(device, %{email: "bad"})
    end
  end

  describe "delete_device/1" do
    test "deletes the device" do
      device = device_fixture()
      assert {:ok, _} = Devices.delete_device(device)
      assert_raise Ecto.NoResultsError, fn -> Devices.get_device!(device.id) end
    end
  end

  describe "change_device/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = Devices.change_device(%Device{})
    end
  end
end
