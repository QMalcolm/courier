defmodule Courier.EbookRunner do
  @moduledoc """
  Handles one-off ebook creation and delivery.

  Creation: converts a list of article URLs to an EPUB via Calibre's
  parse_index() API (no RSS feed or deduplication involved), optionally
  archives to the Calibre library, then broadcasts progress over PubSub.

  Delivery: re-generates the EPUB from the stored article URLs and sends
  it to a single device via SMTP. Each send is tracked in ebook_sends.
  """

  require Logger

  alias Courier.Devices.Device
  alias Courier.Ebooks
  alias Courier.Ebooks.Ebook

  @doc "Starts an async task to convert URLs to EPUB and optionally archive it."
  def create(%Ebook{id: id}) do
    Task.Supervisor.start_child(Courier.TaskSupervisor, fn -> execute_create(id) end)
  end

  @doc "Starts an async task to (re-)generate the EPUB and send it to a device."
  def send_to_device(%Ebook{id: ebook_id}, %Device{} = device) do
    Task.Supervisor.start_child(Courier.TaskSupervisor, fn -> execute_send(ebook_id, device) end)
  end

  # --- Creation ---

  defp execute_create(ebook_id) do
    ebook = Ebooks.get_ebook!(ebook_id)
    Logger.info("[EbookRunner] Starting creation: ebook=#{ebook.id}")

    {:ok, ebook} = Ebooks.update_ebook(ebook, %{status: "running", started_at: DateTime.utc_now()})
    broadcast({:ebook_updated, ebook})

    {status, log, archived} =
      try do
        with_work_dir(fn work_dir ->
          recipe_file = Path.join(work_dir, "ebook.recipe")
          epub_file = Path.join(work_dir, "output.epub")
          File.write!(recipe_file, to_python(ebook))

          case run_convert(recipe_file, epub_file) do
            {:ok, convert_log} ->
              if epub_has_articles?(epub_file) do
                {archive_log, did_archive} = maybe_archive(epub_file)
                {"success", convert_log <> archive_log, did_archive}
              else
                msg = "=== result ===\nNo article content could be extracted. URLs may be paywalled or require JavaScript rendering.\n"
                {"failure", convert_log <> msg, false}
              end

            {:error, convert_log} ->
              {"failure", convert_log, false}
          end
        end)
      rescue
        e -> {"failure", "=== error ===\n#{Exception.message(e)}\n", false}
      end

    {:ok, finished} =
      Ebooks.update_ebook(ebook, %{
        status: status,
        finished_at: DateTime.utc_now(),
        log_output: log,
        archived: archived
      })

    Logger.info("[EbookRunner] Finished creation: ebook=#{ebook.id} status=#{status}")
    broadcast({:ebook_updated, finished})
  end

  # --- Send ---

  defp execute_send(ebook_id, device) do
    ebook = Ebooks.get_ebook!(ebook_id)
    Logger.info("[EbookRunner] Sending: ebook=#{ebook.id} device=#{device.email}")

    {:ok, send} =
      Ebooks.create_send(%{ebook_id: ebook.id, device_id: device.id, status: "running"})

    broadcast({:ebook_updated, Ebooks.get_ebook!(ebook.id)})

    {send_status, sent_at} =
      try do
        with_work_dir(fn work_dir ->
          recipe_file = Path.join(work_dir, "ebook.recipe")
          epub_file = Path.join(work_dir, "output.epub")
          File.write!(recipe_file, to_python(ebook))

          with {:ok, _} <- run_convert(recipe_file, epub_file),
               true <- epub_has_articles?(epub_file),
               {:ok, _} <- run_smtp(epub_file, ebook, device) do
            {"success", DateTime.utc_now()}
          else
            _ -> {"failure", nil}
          end
        end)
      rescue
        _ -> {"failure", nil}
      end

    {:ok, _} = Ebooks.update_send(send, %{status: send_status, sent_at: sent_at})

    Logger.info("[EbookRunner] Send finished: ebook=#{ebook.id} device=#{device.email} status=#{send_status}")
    broadcast({:ebook_updated, Ebooks.get_ebook!(ebook.id)})
  end

  # --- Python recipe generation ---

  defp to_python(%Ebook{} = ebook) do
    articles_lines =
      ebook.articles
      |> Enum.map_join("\n", fn article ->
        "            {'title': '#{esc_py(article.title || "")}', 'url': '#{esc_py(article.url)}'},"
      end)

    """
    from calibre.web.feeds.news import BasicNewsRecipe


    class CourierEbook(BasicNewsRecipe):
        title             = '#{esc_py(ebook.title)}'
        no_stylesheets    = True
        remove_javascript = True

        def parse_index(self):
            return [('Articles', [
    #{articles_lines}
            ])]
    """
  end

  # Escapes a string for safe embedding in a Python single-quoted string literal.
  defp esc_py(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("'", "\\'")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "")
  end

  # --- Calibre helpers ---

  defp epub_has_articles?(epub_file) do
    case :zip.list_dir(String.to_charlist(epub_file)) do
      {:ok, entries} ->
        Enum.any?(entries, fn
          {:zip_file, name, _, _, _, _} -> to_string(name) =~ ~r/article_\d+/
          _ -> false
        end)

      _ ->
        true
    end
  end

  defp run_convert(recipe_file, epub_file) do
    cmd(calibre_bin("ebook-convert"), [recipe_file, epub_file], "ebook-convert")
  end

  defp maybe_archive(epub_file) do
    case System.get_env("COURIER_CALIBRE_LIBRARY") do
      nil ->
        {"", false}

      library_path ->
        :global.trans({:calibredb_lock, :archive}, fn ->
          case cmd(
                 calibre_bin("calibredb"),
                 ["add", epub_file, "--library-path", library_path],
                 "calibredb add"
               ) do
            {:ok, log} -> {log, true}
            {:error, log} -> {log, false}
          end
        end)
    end
  end

  defp run_smtp(epub_file, ebook, device) do
    %{
      from: from,
      username: username,
      password: password,
      relay: relay,
      port: port,
      encryption: encryption
    } = smtp_config()

    subject = "#{ebook.title} — #{Date.utc_today()}"

    args = [
      "--username", username,
      "--password", password,
      "--relay", relay,
      "--port", port,
      "--encryption", encryption,
      "--subject", subject,
      "--attachment", epub_file,
      from,
      device.email,
      "Delivered by Courier"
    ]

    cmd(calibre_bin("calibre-smtp"), args, "calibre-smtp")
  end

  defp cmd(bin, args, label) do
    header = "=== #{label} ===\n"

    case System.cmd(bin, args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, header <> output <> "\n"}
      {output, code} -> {:error, header <> output <> "\nExited with code #{code}\n"}
    end
  rescue
    e -> {:error, "=== #{label} ===\nFailed to start process: #{Exception.message(e)}\n"}
  end

  defp calibre_bin(name) do
    Path.join(System.get_env("COURIER_CALIBRE_PATH", "/opt/calibre"), name)
  end

  defp smtp_config do
    %{
      from: System.get_env("COURIER_SMTP_FROM", ""),
      username: System.get_env("COURIER_SMTP_USERNAME", ""),
      password: System.get_env("COURIER_SMTP_PASSWORD", ""),
      relay: System.get_env("COURIER_SMTP_RELAY", "smtp.gmail.com"),
      port: System.get_env("COURIER_SMTP_PORT", "587"),
      encryption: System.get_env("COURIER_SMTP_ENCRYPTION", "TLS")
    }
  end

  defp with_work_dir(fun) do
    work_dir =
      Path.join(System.tmp_dir!(), "courier_ebook_#{System.unique_integer([:positive])}")

    File.mkdir_p!(work_dir)

    try do
      fun.(work_dir)
    after
      File.rm_rf!(work_dir)
    end
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(Courier.PubSub, "ebooks", message)
  end
end
