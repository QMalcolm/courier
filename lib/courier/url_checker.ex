defmodule Courier.UrlChecker do
  @moduledoc """
  Checks whether article URLs are reachable before committing to an ebook
  creation. All URLs are checked concurrently; total wait time is bounded
  by the slowest single URL, not the sum.

  Uses HEAD requests where supported (no body download), falling back to
  GET on 405. Follows redirects up to 5 hops using the same logic as
  FeedParser.
  """

  @timeout 8_000
  @max_redirects 5

  @doc """
  Checks all URLs concurrently. Returns a list of `{url, :ok}` or
  `{url, {:error, reason}}` tuples in the same order as the input.
  """
  @spec check_all([String.t()]) :: [{String.t(), :ok | {:error, String.t()}}]
  def check_all(urls) do
    stream =
      Task.async_stream(
        urls,
        &check/1,
        timeout: @timeout + 1_000,
        max_concurrency: 20,
        on_timeout: :kill_task
      )

    urls
    |> Enum.zip(stream)
    |> Enum.map(fn
      {url, {:ok, :ok}} -> {url, :ok}
      {url, {:ok, {:error, reason}}} -> {url, {:error, reason}}
      {url, {:exit, :timeout}} -> {url, {:error, "timed out"}}
      {url, {:exit, reason}} -> {url, {:error, inspect(reason)}}
    end)
  end

  @doc "Checks a single URL. Returns `:ok` or `{:error, reason}`."
  @spec check(String.t()) :: :ok | {:error, String.t()}
  def check(url), do: request(url, :head, @max_redirects)

  defp request(_url, _method, 0), do: {:error, "too many redirects"}

  defp request(url, method, redirects_left) do
    req = Finch.build(method, url, [{"user-agent", "Courier/1.0"}])

    case Finch.request(req, Courier.Finch, receive_timeout: @timeout) do
      {:ok, %{status: status, headers: headers}} when status in 301..308 ->
        case List.keyfind(headers, "location", 0) do
          {"location", location} ->
            request(resolve_url(url, location), :get, redirects_left - 1)

          nil ->
            {:error, "redirect with no Location header"}
        end

      {:ok, %{status: 405}} when method == :head ->
        request(url, :get, redirects_left)

      {:ok, %{status: status}} ->
        status_result(status)

      {:error, reason} ->
        {:error, error_message(reason)}
    end
  rescue
    ArgumentError -> {:error, "invalid URL"}
  end

  defp status_result(s) when s in 200..299, do: :ok
  defp status_result(401), do: {:error, "requires authentication (HTTP 401)"}
  defp status_result(403), do: {:error, "access forbidden (HTTP 403)"}
  defp status_result(404), do: {:error, "not found (HTTP 404)"}
  defp status_result(410), do: {:error, "page removed (HTTP 410)"}
  defp status_result(429), do: {:error, "rate limited (HTTP 429)"}
  defp status_result(s) when s in 400..499, do: {:error, "HTTP #{s}"}
  defp status_result(s) when s in 500..599, do: {:error, "server error (HTTP #{s})"}
  defp status_result(s), do: {:error, "unexpected status (HTTP #{s})"}

  defp error_message(%{reason: :nxdomain}), do: "domain not found"
  defp error_message(%{reason: :econnrefused}), do: "connection refused"
  defp error_message(%{reason: :timeout}), do: "timed out"
  defp error_message(reason), do: inspect(reason)

  defp resolve_url(_base, "http" <> _ = location), do: location

  defp resolve_url(base, location) do
    uri = URI.parse(base)
    "#{uri.scheme}://#{uri.host}#{location}"
  end
end
