defmodule Courier.FeedParser do
  @moduledoc """
  Fetches a feed URL and extracts article GUIDs.
  Handles RSS 2.0 (via <item>/<guid> or <link>) and
  Atom (via <entry>/<id> or <link href="...">).
  """

  @spec fetch_guids(String.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def fetch_guids(url) do
    case fetch_body(url) do
      {:ok, body} -> {:ok, parse_guids(body)}
      {:error, _} = err -> err
    end
  end

  def extract_rss_guid(item_block) do
    regex_first(item_block, [
      ~r/<guid[^>]*>(.*?)<\/guid>/s,
      ~r/<link>(.*?)<\/link>/s
    ])
  end

  def extract_atom_id(entry_block) do
    regex_first(entry_block, [
      ~r/<id[^>]*>(.*?)<\/id>/s,
      ~r/<link[^>]*href="([^"]+)"/
    ])
  end

  defp fetch_body(url, redirects_left \\ 5) do
    request = Finch.build(:get, url, [{"user-agent", "Courier/1.0"}])

    case Finch.request(request, Courier.Finch) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, headers: headers}} when status in [301, 302, 307, 308] and redirects_left > 0 ->
        case List.keyfind(headers, "location", 0) do
          {"location", location} -> fetch_body(location, redirects_left - 1)
          nil -> {:error, "redirect with no Location header"}
        end

      {:ok, %{status: status}} ->
        {:error, "upstream returned #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp parse_guids(body) do
    cond do
      String.contains?(body, "<rss") ->
        collect_guids(body, ~r/(<item[\s>].*?<\/item>)/s, &extract_rss_guid/1)

      String.contains?(body, "http://www.w3.org/2005/Atom") ->
        collect_guids(body, ~r/(<entry[\s>].*?<\/entry>)/s, &extract_atom_id/1)

      true ->
        []
    end
  end

  defp collect_guids(body, item_regex, extractor) do
    body
    |> Regex.scan(item_regex)
    |> Enum.flat_map(fn [item_block | _] ->
      case extractor.(item_block) do
        nil -> []
        guid -> [guid]
      end
    end)
  end

  defp regex_first(_text, []), do: nil

  defp regex_first(text, [regex | rest]) do
    case Regex.run(regex, text, capture: :all_but_first) do
      [value] -> String.trim(value)
      _ -> regex_first(text, rest)
    end
  end
end
