defmodule Courier.Ebooks.Ebook do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending running success failure)

  schema "ebooks" do
    field :title, :string
    field :status, :string, default: "pending"
    field :log_output, :string
    field :archived, :boolean, default: false
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime

    has_many :articles, Courier.Ebooks.EbookArticle, preload_order: [asc: :position]
    has_many :sends, Courier.Ebooks.EbookSend

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ebook, attrs) do
    ebook
    |> cast(attrs, [:title, :status, :log_output, :archived, :started_at, :finished_at])
    |> validate_required([:title, :status])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_inclusion(:status, @statuses)
  end
end
