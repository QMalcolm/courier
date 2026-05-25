defmodule CourierWeb.EbookLive.Index do
  use CourierWeb, :live_view

  alias Courier.Ebooks
  alias Courier.EbookRunner
  alias Courier.UrlChecker

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Courier.PubSub, "ebooks")
    end

    {:ok,
     socket
     |> assign(:ebooks, Ebooks.list_ebooks())
     |> assign(:errors, [])
     |> assign(:pdf_urls, [])
     |> assign(:title, "")
     |> assign(:urls_text, "")}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action)}
  end

  defp apply_action(socket, :index) do
    assign(socket, :page_title, "Ebooks")
  end

  defp apply_action(socket, :new) do
    socket
    |> assign(:page_title, "New Ebook")
    |> assign(:title, "")
    |> assign(:urls_text, "")
    |> assign(:errors, [])
    |> assign(:pdf_urls, [])
  end

  @impl true
  def handle_info({:ebook_updated, _}, socket) do
    {:noreply, assign(socket, :ebooks, Ebooks.list_ebooks())}
  end

  @impl true
  def handle_event("create", %{"title" => title, "urls_text" => urls_text}, socket) do
    title = String.trim(title)
    urls = parse_urls(urls_text)
    errors = validate_params(title, urls)

    {reach_errors, pdf_urls} = reachability_check(urls)

    cond do
      errors != [] ->
        {:noreply, assign(socket, errors: errors, pdf_urls: [])}

      reach_errors != [] ->
        {:noreply, assign(socket, errors: reach_errors, pdf_urls: pdf_urls)}

      true ->
        {:ok, ebook} = Ebooks.create_ebook_with_articles(title, urls)
        EbookRunner.create(ebook)

        {:noreply,
         socket
         |> assign(:ebooks, Ebooks.list_ebooks())
         |> push_navigate(to: ~p"/ebooks/#{ebook}")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    ebook = Ebooks.get_ebook!(id)
    {:ok, _} = Ebooks.delete_ebook(ebook)
    {:noreply, assign(socket, :ebooks, Ebooks.list_ebooks())}
  end

  defp parse_urls(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp validate_params(title, urls) do
    [
      if(title == "", do: "Title can't be blank"),
      if(urls == [], do: "Must include at least one URL")
      | Enum.flat_map(urls, &url_error/1)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp reachability_check(urls) do
    results = UrlChecker.check_all(urls)
    errors = for {url, {:error, reason}} <- results, do: "#{url}: #{reason}"
    pdf_urls = for {url, :pdf} <- results, do: url
    {errors, pdf_urls}
  end

  defp url_error(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        if private_host?(host), do: ["#{url}: must be a public URL"], else: []

      _ ->
        ["#{url}: must be a valid http or https URL"]
    end
  end

  defp private_host?(host) do
    host in ["localhost", "127.0.0.1", "::1"] or
      String.starts_with?(host, "192.168.") or
      String.starts_with?(host, "10.") or
      Regex.match?(~r/^172\.(1[6-9]|2\d|3[01])\./, host)
  end

  def status_class("success"), do: "bg-green-100 text-green-800"
  def status_class("failure"), do: "bg-red-100 text-red-800"
  def status_class("running"), do: "bg-blue-100 text-blue-800"
  def status_class(_), do: "bg-zinc-100 text-zinc-600"

  def duration(%{started_at: nil}), do: "—"
  def duration(%{finished_at: nil}), do: "running…"

  def duration(%{started_at: s, finished_at: f}) do
    "#{DateTime.diff(f, s, :second)}s"
  end
end
