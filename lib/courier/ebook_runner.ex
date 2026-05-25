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

    {:ok, ebook} =
      Ebooks.update_ebook(ebook, %{
        status: "running",
        started_at: DateTime.utc_now(),
        finished_at: nil,
        log_output: nil,
        archived: false
      })
    broadcast({:ebook_updated, ebook})

    {status, log, archived} =
      try do
        with_work_dir(fn work_dir ->
          recipe_file = Path.join(work_dir, "ebook.recipe")
          epub_file = Path.join(work_dir, "output.epub")
          {prepared_articles, pdf_log} = prepare_articles(ebook.articles, work_dir)
          File.write!(recipe_file, to_python(ebook.title, prepared_articles))

          case run_convert(recipe_file, epub_file) do
            {:ok, convert_log} ->
              if epub_has_articles?(epub_file) do
                {archive_log, did_archive} = maybe_archive(epub_file)
                {"success", pdf_log <> convert_log <> archive_log, did_archive}
              else
                msg = "=== result ===\nNo article content could be extracted. URLs may be paywalled or require JavaScript rendering.\n"
                {"failure", pdf_log <> convert_log <> msg, false}
              end

            {:error, convert_log} ->
              {"failure", pdf_log <> convert_log, false}
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
          {prepared_articles, _pdf_log} = prepare_articles(ebook.articles, work_dir)
          File.write!(recipe_file, to_python(ebook.title, prepared_articles))

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

  defp to_python(title, articles) do
    articles_lines =
      articles
      |> Enum.map_join("\n", fn article ->
        "            {'title': '#{esc_py(article.title || "")}', 'url': '#{esc_py(article.url)}'},"
      end)

    """
    from calibre.web.feeds.news import BasicNewsRecipe


    class CourierEbook(BasicNewsRecipe):
        title             = '#{esc_py(title)}'
        no_stylesheets    = True
        remove_javascript = True

        def parse_index(self):
            return [('Articles', [
    #{articles_lines}
            ])]
    """
  end

  # --- PDF preparation ---

  # Checks each article URL. PDFs are downloaded and converted to HTML via
  # Calibre, then referenced as file:// URLs so parse_index can include them.
  # Falls back to the original URL on any failure; Calibre will handle it
  # (likely producing an empty article) rather than aborting the whole ebook.
  defp prepare_articles(articles, work_dir) do
    {prepared, logs} =
      articles
      |> Enum.map(fn article ->
        if pdf_url?(article.url) do
          case convert_pdf(article, work_dir) do
            {:ok, html_path, log} -> {%{article | url: "file://#{html_path}"}, log}
            {:error, log} -> {article, log}
          end
        else
          article = if is_nil(article.title), do: fetch_title(article), else: article
          {article, ""}
        end
      end)
      |> Enum.unzip()

    combined_log = logs |> Enum.reject(&(&1 == "")) |> Enum.join()
    {prepared, combined_log}
  end

  defp fetch_title(article) do
    req = Finch.build(:get, article.url, [{"user-agent", "Courier/1.0"}])

    case Finch.request(req, Courier.Finch, receive_timeout: 10_000) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        case extract_title(body) do
          nil -> article
          title ->
            {:ok, updated} = Ebooks.update_article(article, %{title: title})
            updated
        end

      _ ->
        article
    end
  rescue
    _ -> article
  end

  defp extract_title(html) do
    case Regex.run(~r/<title[^>]*>(.*?)<\/title>/si, html, capture: :all_but_first) do
      [raw] ->
        decoded = raw |> String.trim() |> decode_html_entities()
        if decoded == "", do: nil, else: decoded

      _ ->
        nil
    end
  end

  defp decode_html_entities(text) do
    text
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&apos;", "'")
    |> String.replace("&nbsp;", " ")
    |> then(&Regex.replace(~r/&#(\d+);/, &1, fn _, n -> <<String.to_integer(n)::utf8>> end))
    |> then(&Regex.replace(~r/&#x([0-9a-fA-F]+);/, &1, fn _, h -> <<String.to_integer(h, 16)::utf8>> end))
  end

  defp pdf_url?(url) do
    req = Finch.build(:head, url, [{"user-agent", "Courier/1.0"}])

    case Finch.request(req, Courier.Finch, receive_timeout: 8_000) do
      {:ok, %{status: status, headers: headers}} when status in 200..299 ->
        case List.keyfind(headers, "content-type", 0) do
          {"content-type", ct} -> String.contains?(ct, "application/pdf")
          nil -> false
        end

      _ ->
        false
    end
  rescue
    _ -> false
  end

  defp convert_pdf(article, work_dir) do
    pdf_path = Path.join(work_dir, "article_#{article.position}.pdf")
    txt_path = Path.join(work_dir, "article_#{article.position}.txt")
    html_path = Path.join(work_dir, "article_#{article.position}.html")
    header = "=== pdf #{article.url} ===\n"

    with :ok <- download_file(article.url, pdf_path),
         {:ok, convert_log} <-
           cmd(calibre_bin("ebook-convert"), [pdf_path, txt_path], "pdf-to-txt") do
      File.write!(html_path, text_to_html(File.read!(txt_path)))
      {:ok, html_path, header <> convert_log}
    else
      {:error, reason} -> {:error, header <> "Failed: #{reason}\n"}
    end
  end

  defp text_to_html(text) do
    escaped =
      text
      |> String.replace("&", "&amp;")
      |> String.replace("<", "&lt;")
      |> String.replace(">", "&gt;")

    """
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"/></head>
    <body><pre style="white-space: pre-wrap; font-family: serif; font-size: 1em;">#{escaped}</pre></body>
    </html>
    """
  end

  defp download_file(url, path) do
    req = Finch.build(:get, url, [{"user-agent", "Courier/1.0"}])

    case Finch.request(req, Courier.Finch, receive_timeout: 60_000) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        File.write!(path, body)
        :ok

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, e} ->
        {:error, Exception.message(e)}
    end
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
    cmd(calibre_bin("ebook-convert"), [recipe_file, epub_file, "--flow-size", "0"], "ebook-convert")
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
