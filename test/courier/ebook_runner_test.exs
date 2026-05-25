defmodule Courier.EbookRunnerTest do
  use Courier.DataCase, async: false
  import Courier.Fixtures

  alias Courier.EbookRunner
  alias Courier.Ebooks

  setup do
    Phoenix.PubSub.subscribe(Courier.PubSub, "ebooks")
    :ok
  end

  describe "create/1" do
    test "starts async task that runs to completion" do
      ebook = ebook_fixture()
      assert {:ok, _pid} = EbookRunner.create(ebook)

      assert_receive {:ebook_updated, %{status: "running"}}, 3_000
      assert_receive {:ebook_updated, %{status: final_status}}, 15_000
      assert final_status in ["success", "failure"]

      updated = Ebooks.get_ebook!(ebook.id)
      assert updated.status == final_status
      assert updated.started_at != nil
      assert updated.finished_at != nil
      assert updated.log_output != nil
    end
  end

  describe "send_to_device/2" do
    test "starts async task that runs to completion" do
      ebook = ebook_fixture()
      {:ok, ebook} = Ebooks.update_ebook(ebook, %{status: "success"})
      device = device_fixture()

      assert {:ok, _pid} = EbookRunner.send_to_device(ebook, device)

      # First broadcast: EbookSend created with "running" status
      assert_receive {:ebook_updated, _}, 3_000
      # Second broadcast: send completed (failure since Calibre is unavailable)
      assert_receive {:ebook_updated, _}, 15_000
    end
  end
end
