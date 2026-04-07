defmodule CourierWeb.FeedProxyController do
  use CourierWeb, :controller

  alias Courier.DeliveredArticles
  alias Courier.FeedParser

  def show(conn, %{"run_id" => run_id, "recipe_id" => recipe_id, "url" => url}) do
    known_guids = DeliveredArticles.list_guids_for_recipe(recipe_id)

    case fetch_feed(url) do
      {:ok, body, content_type} ->
        {filtered_body, served_guids} = filter_feed(body, known_guids)
        store_served_guids(run_id, served_guids)

        conn
        |> put_resp_content_type(content_type)
        |> send_resp(200, filtered_body)

      {:error, reason} ->
        send_resp(conn, 502, "Failed to fetch feed: #{reason}")
    end
  end

  defp fetch_feed(url) do
    request = Finch.build(:get, url, [{"user-agent", "Courier/1.0"}])

    case Finch.request(request, Courier.Finch) do
      {:ok, %{status: 200, body: body, headers: headers}} ->
        content_type =
          case Enum.find(headers, fn {k, _} -> String.downcase(k) == "content-type" end) do
            {_, v} -> v
            nil -> "application/rss+xml"
          end

        {:ok, body, content_type}

      {:ok, %{status: status}} ->
        {:error, "upstream returned #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp filter_feed(body, known_guids) do
    cond do
      String.contains?(body, "<rss") ->
        filter_items(body, ~r/(<item[\s>].*?<\/item>)/s, "item", known_guids, &extract_rss_guid/1)

      String.contains?(body, "http://www.w3.org/2005/Atom") ->
        filter_items(body, ~r/(<entry[\s>].*?<\/entry>)/s, "entry", known_guids, &extract_atom_id/1)

      true ->
        {body, []}
    end
  end

  defp filter_items(body, item_regex, item_tag, known_guids, guid_extractor) do
    parts = Regex.split(item_regex, body, include_captures: true)

    {kept_parts, served_guids} =
      Enum.reduce(parts, {[], []}, fn part, {kept, served} ->
        if String.starts_with?(part, "<#{item_tag}") do
          case guid_extractor.(part) do
            nil ->
              # Can't extract a guid — keep the item but don't track it
              {[part | kept], served}

            guid ->
              if MapSet.member?(known_guids, guid) do
                {kept, served}
              else
                {[part | kept], [guid | served]}
              end
          end
        else
          {[part | kept], served}
        end
      end)

    filtered_body = kept_parts |> Enum.reverse() |> IO.iodata_to_binary()
    {filtered_body, served_guids}
  end

  defp extract_rss_guid(item_block), do: FeedParser.extract_rss_guid(item_block)
  defp extract_atom_id(entry_block), do: FeedParser.extract_atom_id(entry_block)

  defp store_served_guids(_run_id, []), do: :ok

  defp store_served_guids(run_id, new_guids) do
    existing =
      case :ets.lookup(:delivery_buffer, run_id) do
        [{^run_id, guids}] -> guids
        [] -> []
      end

    :ets.insert(:delivery_buffer, {run_id, existing ++ new_guids})
  end
end
