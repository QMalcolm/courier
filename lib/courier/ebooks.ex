defmodule Courier.Ebooks do
  import Ecto.Query
  alias Courier.Repo
  alias Courier.Ebooks.{Ebook, EbookArticle, EbookSend}

  def list_ebooks(limit \\ 50) do
    Repo.all(
      from e in Ebook,
        order_by: [desc: e.inserted_at],
        limit: ^limit,
        preload: [articles: ^from(a in EbookArticle, order_by: a.position)]
    )
  end

  def get_ebook!(id) do
    Repo.get!(Ebook, id)
    |> Repo.preload([
      articles: from(a in EbookArticle, order_by: a.position),
      sends: [:device]
    ])
  end

  @doc """
  Creates an ebook and its article rows in a single transaction.
  URLs must already be validated by the caller.
  """
  def create_ebook_with_articles(title, urls) do
    Repo.transaction(fn ->
      ebook =
        %Ebook{}
        |> Ebook.changeset(%{title: title})
        |> Repo.insert!()

      urls
      |> Enum.with_index()
      |> Enum.each(fn {url, idx} ->
        %EbookArticle{}
        |> EbookArticle.changeset(%{url: url, position: idx, ebook_id: ebook.id})
        |> Repo.insert!()
      end)

      Repo.preload(ebook, articles: from(a in EbookArticle, order_by: a.position))
    end)
  end

  def update_ebook(%Ebook{} = ebook, attrs) do
    ebook
    |> Ebook.changeset(attrs)
    |> Repo.update()
  end

  def update_article(%EbookArticle{} = article, attrs) do
    article
    |> EbookArticle.changeset(attrs)
    |> Repo.update()
  end

  def delete_ebook(%Ebook{} = ebook) do
    Repo.delete(ebook)
  end

  def create_send(attrs) do
    %EbookSend{}
    |> EbookSend.changeset(attrs)
    |> Repo.insert()
  end

  def update_send(%EbookSend{} = send, attrs) do
    send
    |> EbookSend.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Marks ebooks stuck in "running" as failed. Called on startup to recover
  from crashes that interrupted an in-progress conversion.
  """
  def mark_stale_ebooks_as_failed do
    now = DateTime.utc_now()

    Repo.update_all(
      from(e in Ebook, where: e.status == "running"),
      set: [
        status: "failure",
        finished_at: now,
        log_output: "Ebook creation was interrupted (server restarted while running)."
      ]
    )
  end
end
