defmodule Courier.FeedParserTest do
  use ExUnit.Case, async: false

  alias Courier.FeedParser

  @rss_feed """
  <?xml version="1.0"?>
  <rss version="2.0">
    <channel>
      <title>Test</title>
      <item>
        <title>Article One</title>
        <guid>https://example.com/1</guid>
        <link>https://example.com/1</link>
      </item>
      <item>
        <title>Article Two</title>
        <link>https://example.com/2</link>
      </item>
    </channel>
  </rss>
  """

  @atom_feed """
  <?xml version="1.0"?>
  <feed xmlns="http://www.w3.org/2005/Atom">
    <title>Test Atom</title>
    <entry>
      <title>Entry One</title>
      <id>urn:uuid:atom-1</id>
    </entry>
    <entry>
      <title>Entry Two</title>
      <link href="https://example.com/atom/2"/>
    </entry>
  </feed>
  """

  describe "extract_rss_guid/1" do
    test "extracts guid element" do
      item = "<item><guid>https://example.com/1</guid></item>"
      assert FeedParser.extract_rss_guid(item) == "https://example.com/1"
    end

    test "falls back to link element when no guid" do
      item = "<item><link>https://example.com/2</link></item>"
      assert FeedParser.extract_rss_guid(item) == "https://example.com/2"
    end

    test "returns nil when neither guid nor link present" do
      assert nil == FeedParser.extract_rss_guid("<item><title>No ID</title></item>")
    end

    test "trims whitespace from guid" do
      item = "<item><guid>  https://example.com/3  </guid></item>"
      assert FeedParser.extract_rss_guid(item) == "https://example.com/3"
    end
  end

  describe "extract_atom_id/1" do
    test "extracts id element" do
      entry = "<entry><id>urn:uuid:abc</id></entry>"
      assert FeedParser.extract_atom_id(entry) == "urn:uuid:abc"
    end

    test "falls back to link href attribute" do
      entry = ~s(<entry><link href="https://example.com/atom/1"/></entry>)
      assert FeedParser.extract_atom_id(entry) == "https://example.com/atom/1"
    end

    test "returns nil when neither id nor link present" do
      assert nil == FeedParser.extract_atom_id("<entry><title>X</title></entry>")
    end
  end

  describe "fetch_guids/1" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "parses RSS and Atom feeds and returns guids", %{bypass: bypass} do
      port = bypass.port

      Bypass.expect(bypass, fn conn ->
        case {conn.method, conn.request_path} do
          {"GET", "/rss"} ->
            conn
            |> Plug.Conn.put_resp_content_type("application/rss+xml")
            |> Plug.Conn.send_resp(200, @rss_feed)

          {"GET", "/atom"} ->
            conn
            |> Plug.Conn.put_resp_content_type("application/atom+xml")
            |> Plug.Conn.send_resp(200, @atom_feed)
        end
      end)

      assert {:ok, rss_guids} = FeedParser.fetch_guids("http://localhost:#{port}/rss")
      assert "https://example.com/1" in rss_guids
      assert "https://example.com/2" in rss_guids

      assert {:ok, atom_guids} = FeedParser.fetch_guids("http://localhost:#{port}/atom")
      assert "urn:uuid:atom-1" in atom_guids
      assert "https://example.com/atom/2" in atom_guids
    end

    test "follows absolute and relative redirects", %{bypass: bypass} do
      port = bypass.port

      Bypass.expect(bypass, fn conn ->
        case conn.request_path do
          "/abs-redir" ->
            conn
            |> Plug.Conn.put_resp_header("location", "http://localhost:#{port}/rss")
            |> Plug.Conn.send_resp(301, "")

          "/rel-redir" ->
            conn
            |> Plug.Conn.put_resp_header("location", "/rss")
            |> Plug.Conn.send_resp(301, "")

          "/rss" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/rss+xml")
            |> Plug.Conn.send_resp(200, @rss_feed)
        end
      end)

      assert {:ok, abs_guids} = FeedParser.fetch_guids("http://localhost:#{port}/abs-redir")
      assert length(abs_guids) > 0

      assert {:ok, rel_guids} = FeedParser.fetch_guids("http://localhost:#{port}/rel-redir")
      assert length(rel_guids) > 0
    end

    test "returns error for non-200 status", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/gone", fn conn ->
        Plug.Conn.send_resp(conn, 404, "Not Found")
      end)

      assert {:error, _} = FeedParser.fetch_guids("http://localhost:#{bypass.port}/gone")
    end

    test "returns error for connection failure" do
      assert {:error, _} = FeedParser.fetch_guids("http://127.0.0.1:1/feed")
    end

    test "returns error for invalid URL" do
      assert {:error, _} = FeedParser.fetch_guids("not-a-url")
    end

    test "returns error for redirect with no Location header", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/no-location", fn conn ->
        Plug.Conn.send_resp(conn, 301, "")
      end)

      assert {:error, "redirect with no Location header"} =
               FeedParser.fetch_guids("http://localhost:#{bypass.port}/no-location")
    end

    test "returns empty list for non-feed body", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/html", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/html")
        |> Plug.Conn.send_resp(200, "<html><body>Not a feed</body></html>")
      end)

      assert {:ok, []} = FeedParser.fetch_guids("http://localhost:#{bypass.port}/html")
    end

    test "skips items with no extractable guid", %{bypass: bypass} do
      feed_no_guids = """
      <?xml version="1.0"?>
      <rss version="2.0"><channel>
        <item><title>No ID Here</title></item>
      </channel></rss>
      """

      Bypass.expect_once(bypass, "GET", "/no-guid", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/rss+xml")
        |> Plug.Conn.send_resp(200, feed_no_guids)
      end)

      assert {:ok, []} = FeedParser.fetch_guids("http://localhost:#{bypass.port}/no-guid")
    end

  end
end
