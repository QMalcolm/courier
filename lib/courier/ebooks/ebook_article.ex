defmodule Courier.Ebooks.EbookArticle do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ebook_articles" do
    field :url, :string
    field :title, :string
    field :position, :integer

    belongs_to :ebook, Courier.Ebooks.Ebook

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(article, attrs) do
    article
    |> cast(attrs, [:url, :title, :position, :ebook_id])
    |> validate_required([:url, :position, :ebook_id])
    |> validate_url()
  end

  defp validate_url(changeset) do
    validate_change(changeset, :url, fn :url, url ->
      case URI.parse(url) do
        %URI{scheme: scheme, host: host}
        when scheme in ["http", "https"] and is_binary(host) and host != "" ->
          if private_host?(host), do: [url: "must be a public URL"], else: []

        _ ->
          [url: "must be a valid http or https URL"]
      end
    end)
  end

  # Blocks RFC 1918 and loopback addresses to prevent SSRF via Calibre subprocess.
  defp private_host?(host) do
    host in ["localhost", "127.0.0.1", "::1"] or
      String.starts_with?(host, "192.168.") or
      String.starts_with?(host, "10.") or
      Regex.match?(~r/^172\.(1[6-9]|2\d|3[01])\./, host)
  end
end
