defmodule Courier.Ebooks.EbookSend do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(running success failure)

  schema "ebook_sends" do
    field :status, :string
    field :sent_at, :utc_datetime

    belongs_to :ebook, Courier.Ebooks.Ebook
    belongs_to :device, Courier.Devices.Device

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(send, attrs) do
    send
    |> cast(attrs, [:status, :sent_at, :ebook_id, :device_id])
    |> validate_required([:status, :ebook_id, :device_id])
    |> validate_inclusion(:status, @statuses)
  end
end
