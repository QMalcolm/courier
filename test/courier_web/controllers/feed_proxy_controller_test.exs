defmodule CourierWeb.FeedProxyControllerTest do
  use CourierWeb.ConnCase
  import Courier.Fixtures

  @rss_feed """
  <?xml version="1.0"?>
  <rss version="2.0"><channel>
    <item><guid>guid-old</guid><title>Old</title></item>
    <item><guid>guid-new</guid><title>New</title></item>
  </channel></rss>
  """

  @atom_feed """
  <?xml version="1.0"?>
  <feed xmlns="http://www.w3.org/2005/Atom">
    <entry><id>atom-old</id><title>Old</title></entry>
    <entry><id>atom-new</id><title>New</title></entry>
  </feed>
  """

  setup do
    bypass = Bypass.open()
    recipe = recipe_fixture()
    {:ok, bypass: bypass, recipe: recipe}
  end

  defp proxy_get(conn, recipe, url, run_id \\ "r") do
    get(
      conn,
      "/proxy/feed?run_id=#{run_id}&recipe_id=#{recipe.id}&url=#{URI.encode_www_form(url)}"
    )
  end

  defp bypass_url(bypass, path), do: "http://localhost:#{bypass.port}#{path}"

  test "proxies RSS feed and filters out already-delivered guids", %{
    conn: conn,
    bypass: bypass,
    recipe: recipe
  } do
    Courier.DeliveredArticles.record_articles(recipe.id, ["guid-old"])

    Bypass.expect_once(bypass, "GET", "/feed", fn c ->
      c
      |> Plug.Conn.put_resp_content_type("application/rss+xml")
      |> Plug.Conn.send_resp(200, @rss_feed)
    end)

    conn = proxy_get(conn, recipe, bypass_url(bypass, "/feed"), "test-1")
    assert response(conn, 200) =~ "guid-new"
    refute response(conn, 200) =~ "guid-old"
  end

  test "stores new guids in ETS delivery buffer", %{conn: conn, bypass: bypass, recipe: recipe} do
    Bypass.expect_once(bypass, "GET", "/feed", fn c ->
      c
      |> Plug.Conn.put_resp_content_type("application/rss+xml")
      |> Plug.Conn.send_resp(200, @rss_feed)
    end)

    run_id = "run-ets-test"
    proxy_get(conn, recipe, bypass_url(bypass, "/feed"), run_id)

    [{^run_id, guids}] = :ets.lookup(:delivery_buffer, run_id)
    assert "guid-new" in guids
    :ets.delete(:delivery_buffer, run_id)
  end

  test "proxies Atom feed and filters delivered entries", %{
    conn: conn,
    bypass: bypass,
    recipe: recipe
  } do
    Courier.DeliveredArticles.record_articles(recipe.id, ["atom-old"])

    Bypass.expect_once(bypass, "GET", "/atom", fn c ->
      c
      |> Plug.Conn.put_resp_content_type("application/atom+xml")
      |> Plug.Conn.send_resp(200, @atom_feed)
    end)

    conn = proxy_get(conn, recipe, bypass_url(bypass, "/atom"), "run-2")
    body = response(conn, 200)
    assert body =~ "atom-new"
    refute body =~ "atom-old"
  end

  test "returns 502 when upstream feed is unreachable", %{conn: conn, recipe: recipe} do
    conn = proxy_get(conn, recipe, "http://127.0.0.1:1/feed")
    assert response(conn, 502) =~ "Failed to fetch feed"
  end

  test "follows upstream redirects", %{conn: conn, bypass: bypass, recipe: recipe} do
    port = bypass.port

    Bypass.expect(bypass, fn c ->
      case c.request_path do
        "/redirect" ->
          c
          |> Plug.Conn.put_resp_header("location", "http://localhost:#{port}/final")
          |> Plug.Conn.send_resp(301, "")

        "/final" ->
          c
          |> Plug.Conn.put_resp_content_type("application/rss+xml")
          |> Plug.Conn.send_resp(200, @rss_feed)
      end
    end)

    conn = proxy_get(conn, recipe, bypass_url(bypass, "/redirect"))
    assert response(conn, 200) =~ "guid-new"
  end

  test "passes through non-RSS/Atom content unchanged", %{
    conn: conn,
    bypass: bypass,
    recipe: recipe
  } do
    body = "<not-rss>some content</not-rss>"

    Bypass.expect_once(bypass, "GET", "/other", fn c ->
      c
      |> Plug.Conn.put_resp_content_type("text/xml")
      |> Plug.Conn.send_resp(200, body)
    end)

    conn = proxy_get(conn, recipe, bypass_url(bypass, "/other"))
    assert response(conn, 200) == body
  end

  test "uses application/rss+xml when upstream omits content-type", %{
    conn: conn,
    bypass: bypass,
    recipe: recipe
  } do
    Bypass.expect_once(bypass, "GET", "/no-ct", fn c ->
      Plug.Conn.send_resp(c, 200, @rss_feed)
    end)

    conn = proxy_get(conn, recipe, bypass_url(bypass, "/no-ct"))
    assert response(conn, 200) =~ "rss"
  end

  test "returns 502 for redirect with no Location header", %{
    conn: conn,
    bypass: bypass,
    recipe: recipe
  } do
    Bypass.expect_once(bypass, "GET", "/no-loc", fn c ->
      Plug.Conn.send_resp(c, 301, "")
    end)

    conn = proxy_get(conn, recipe, bypass_url(bypass, "/no-loc"))
    assert response(conn, 502) =~ "Failed to fetch"
  end

  test "returns 502 for non-2xx non-redirect upstream status", %{
    conn: conn,
    bypass: bypass,
    recipe: recipe
  } do
    Bypass.expect_once(bypass, "GET", "/not-found", fn c ->
      Plug.Conn.send_resp(c, 404, "Not Found")
    end)

    conn = proxy_get(conn, recipe, bypass_url(bypass, "/not-found"))
    assert response(conn, 502) =~ "404"
  end

  test "keeps items with no extractable guid in filtered feed", %{
    conn: conn,
    bypass: bypass,
    recipe: recipe
  } do
    feed_no_guid = """
    <?xml version="1.0"?>
    <rss version="2.0"><channel>
      <item><title>No ID</title></item>
      <item><guid>has-guid</guid><title>With ID</title></item>
    </channel></rss>
    """

    Bypass.expect_once(bypass, "GET", "/no-guid-feed", fn c ->
      c
      |> Plug.Conn.put_resp_content_type("application/rss+xml")
      |> Plug.Conn.send_resp(200, feed_no_guid)
    end)

    conn = proxy_get(conn, recipe, bypass_url(bypass, "/no-guid-feed"))
    body = response(conn, 200)
    assert body =~ "No ID"
    assert body =~ "has-guid"
  end

  test "follows relative redirect preserving host and port", %{
    conn: conn,
    bypass: bypass,
    recipe: recipe
  } do
    Bypass.expect(bypass, fn c ->
      case c.request_path do
        "/relative-redir" ->
          c
          |> Plug.Conn.put_resp_header("location", "/destination")
          |> Plug.Conn.send_resp(301, "")

        "/destination" ->
          c
          |> Plug.Conn.put_resp_content_type("application/rss+xml")
          |> Plug.Conn.send_resp(200, @rss_feed)
      end
    end)

    conn = proxy_get(conn, recipe, bypass_url(bypass, "/relative-redir"))
    assert response(conn, 200) =~ "guid-new"
  end

  test "accumulates guids across multiple requests with the same run_id", %{
    conn: conn,
    bypass: bypass,
    recipe: recipe
  } do
    run_id = "run-accumulate-#{System.unique_integer([:positive])}"

    feed1 = """
    <?xml version="1.0"?>
    <rss version="2.0"><channel>
      <item><guid>guid-first</guid><title>First</title></item>
    </channel></rss>
    """

    feed2 = """
    <?xml version="1.0"?>
    <rss version="2.0"><channel>
      <item><guid>guid-second</guid><title>Second</title></item>
    </channel></rss>
    """

    Bypass.expect(bypass, fn c ->
      body = if c.request_path == "/feed2", do: feed2, else: feed1

      c
      |> Plug.Conn.put_resp_content_type("application/rss+xml")
      |> Plug.Conn.send_resp(200, body)
    end)

    proxy_get(conn, recipe, bypass_url(bypass, "/feed1"), run_id)
    proxy_get(conn, recipe, bypass_url(bypass, "/feed2"), run_id)

    [{^run_id, guids}] = :ets.lookup(:delivery_buffer, run_id)
    assert "guid-first" in guids
    assert "guid-second" in guids
    :ets.delete(:delivery_buffer, run_id)
  end
end
