defmodule Courier.EbooksTest do
  use Courier.DataCase, async: false
  import Courier.Fixtures

  alias Courier.Ebooks
  alias Courier.Ebooks.Ebook
  alias Courier.Ebooks.EbookArticle
  alias Courier.Ebooks.EbookSend

  describe "list_ebooks/1" do
    test "returns ebooks with articles preloaded" do
      e1 = ebook_fixture(%{title: "First"})
      e2 = ebook_fixture(%{title: "Second"})
      ids = Ebooks.list_ebooks() |> Enum.map(& &1.id)
      assert e1.id in ids
      assert e2.id in ids
    end

    test "respects limit" do
      for _ <- 1..5, do: ebook_fixture()
      assert length(Ebooks.list_ebooks(2)) == 2
    end
  end

  describe "get_ebook!/1" do
    test "returns ebook with articles and sends preloaded" do
      ebook = ebook_fixture()
      result = Ebooks.get_ebook!(ebook.id)
      assert is_list(result.articles)
      assert is_list(result.sends)
    end

    test "raises on missing id" do
      assert_raise Ecto.NoResultsError, fn -> Ebooks.get_ebook!(0) end
    end
  end

  describe "create_ebook_with_articles/2" do
    test "creates ebook and article rows in a transaction" do
      urls = ["http://0.0.0.0/a", "http://0.0.0.0/b"]
      assert {:ok, ebook} = Ebooks.create_ebook_with_articles("My Ebook", urls)
      assert ebook.title == "My Ebook"
      assert length(ebook.articles) == 2
      assert Enum.map(ebook.articles, & &1.position) == [0, 1]
    end

    test "articles are ordered by position" do
      {:ok, ebook} =
        Ebooks.create_ebook_with_articles("Test", ["http://0.0.0.0/a", "http://0.0.0.0/b"])

      [first, second] = ebook.articles
      assert first.position == 0
      assert second.position == 1
    end
  end

  describe "update_ebook/2" do
    test "updates ebook status" do
      ebook = ebook_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      assert {:ok, updated} = Ebooks.update_ebook(ebook, %{status: "success", finished_at: now})
      assert updated.status == "success"
    end

    test "rejects invalid status" do
      ebook = ebook_fixture()
      assert {:error, cs} = Ebooks.update_ebook(ebook, %{status: "bad"})
      assert errors_on(cs).status != []
    end
  end

  describe "delete_ebook/1" do
    test "deletes the ebook" do
      ebook = ebook_fixture()
      assert {:ok, _} = Ebooks.delete_ebook(ebook)
      assert_raise Ecto.NoResultsError, fn -> Ebooks.get_ebook!(ebook.id) end
    end
  end

  describe "create_send/1 and update_send/2" do
    test "creates a send record" do
      ebook = ebook_fixture()
      device = device_fixture()

      assert {:ok, send} =
               Ebooks.create_send(%{ebook_id: ebook.id, device_id: device.id, status: "running"})

      assert send.status == "running"
    end

    test "updates the send record" do
      ebook = ebook_fixture()
      device = device_fixture()
      {:ok, send} = Ebooks.create_send(%{ebook_id: ebook.id, device_id: device.id, status: "running"})
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      assert {:ok, updated} = Ebooks.update_send(send, %{status: "success", sent_at: now})
      assert updated.status == "success"
    end

    test "rejects invalid send status" do
      ebook = ebook_fixture()
      device = device_fixture()
      assert {:error, cs} =
               Ebooks.create_send(%{ebook_id: ebook.id, device_id: device.id, status: "bad"})
      assert errors_on(cs).status != []
    end
  end

  describe "mark_stale_ebooks_as_failed/0" do
    test "marks running ebooks as failure" do
      {:ok, ebook} =
        Ebooks.create_ebook_with_articles("Stale", ["http://0.0.0.0/a"])
      {:ok, _} = Ebooks.update_ebook(ebook, %{status: "running"})

      Ebooks.mark_stale_ebooks_as_failed()

      updated = Ebooks.get_ebook!(ebook.id)
      assert updated.status == "failure"
      assert updated.log_output =~ "interrupted"
    end

    test "does not affect non-running ebooks" do
      ebook = ebook_fixture()
      {:ok, _} = Ebooks.update_ebook(ebook, %{status: "success"})
      Ebooks.mark_stale_ebooks_as_failed()
      assert Ebooks.get_ebook!(ebook.id).status == "success"
    end
  end

  describe "Ebook changeset" do
    test "requires title" do
      cs = Ebook.changeset(%Ebook{}, %{})
      assert "can't be blank" in errors_on(cs).title
    end

    test "validates title length" do
      cs = Ebook.changeset(%Ebook{}, %{title: String.duplicate("a", 256)})
      assert errors_on(cs).title != []
    end

    test "accepts valid status values" do
      for status <- ~w(pending running success failure) do
        cs = Ebook.changeset(%Ebook{}, %{title: "T", status: status})
        assert cs.valid?
      end
    end
  end

  describe "EbookArticle changeset" do
    test "requires url and position" do
      cs = EbookArticle.changeset(%EbookArticle{}, %{ebook_id: 1})
      assert "can't be blank" in errors_on(cs).url
      assert "can't be blank" in errors_on(cs).position
    end

    test "rejects private IP addresses (SSRF prevention)" do
      for host <- ["localhost", "127.0.0.1", "192.168.1.1", "10.0.0.1", "172.16.0.1", "172.31.0.1"] do
        cs = EbookArticle.changeset(%EbookArticle{}, %{
          url: "http://#{host}/page",
          position: 0,
          ebook_id: 1
        })
        assert "must be a public URL" in errors_on(cs).url, "expected #{host} to be rejected"
      end
    end

    test "accepts public URLs" do
      cs = EbookArticle.changeset(%EbookArticle{}, %{
        url: "https://example.com/article",
        position: 0,
        ebook_id: 1
      })
      assert cs.valid?
    end

    test "rejects non-http schemes" do
      cs = EbookArticle.changeset(%EbookArticle{}, %{
        url: "ftp://example.com/file",
        position: 0,
        ebook_id: 1
      })
      assert errors_on(cs).url != []
    end
  end

  describe "EbookSend changeset" do
    test "requires status, ebook_id, device_id" do
      cs = EbookSend.changeset(%EbookSend{}, %{})
      assert errors_on(cs).status != []
      assert errors_on(cs).ebook_id != []
      assert errors_on(cs).device_id != []
    end

    test "validates status inclusion" do
      cs = EbookSend.changeset(%EbookSend{}, %{status: "bad", ebook_id: 1, device_id: 1})
      assert errors_on(cs).status != []
    end
  end
end
