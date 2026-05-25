defmodule Courier.UrlCheckerTest do
  use ExUnit.Case, async: false

  alias Courier.UrlChecker

  describe "check/1" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "returns :html for 200 text/html response", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/html; charset=utf-8")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert :html = UrlChecker.check("http://localhost:#{bypass.port}/page")
    end

    test "returns :pdf for application/pdf content-type", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/pdf")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert :pdf = UrlChecker.check("http://localhost:#{bypass.port}/doc.pdf")
    end

    test "falls back to GET when HEAD returns 405", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        case conn.method do
          "HEAD" -> Plug.Conn.send_resp(conn, 405, "")
          "GET" ->
            conn
            |> Plug.Conn.put_resp_header("content-type", "text/html")
            |> Plug.Conn.send_resp(200, "")
        end
      end)

      assert :html = UrlChecker.check("http://localhost:#{bypass.port}/page")
    end

    test "follows redirect", %{bypass: bypass} do
      port = bypass.port

      Bypass.expect(bypass, fn conn ->
        case conn.request_path do
          "/old" ->
            conn
            |> Plug.Conn.put_resp_header("location", "http://localhost:#{port}/new")
            |> Plug.Conn.send_resp(301, "")

          "/new" ->
            conn
            |> Plug.Conn.put_resp_header("content-type", "text/html")
            |> Plug.Conn.send_resp(200, "")
        end
      end)

      assert :html = UrlChecker.check("http://localhost:#{bypass.port}/old")
    end

    test "returns error for 404", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn -> Plug.Conn.send_resp(conn, 404, "") end)
      assert {:error, msg} = UrlChecker.check("http://localhost:#{bypass.port}/missing")
      assert msg =~ "404"
    end

    test "returns error for 401", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn -> Plug.Conn.send_resp(conn, 401, "") end)
      assert {:error, msg} = UrlChecker.check("http://localhost:#{bypass.port}/secure")
      assert msg =~ "authentication"
    end

    test "returns error for 403", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn -> Plug.Conn.send_resp(conn, 403, "") end)
      assert {:error, msg} = UrlChecker.check("http://localhost:#{bypass.port}/forbidden")
      assert msg =~ "forbidden"
    end

    test "returns error for 410", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn -> Plug.Conn.send_resp(conn, 410, "") end)
      assert {:error, msg} = UrlChecker.check("http://localhost:#{bypass.port}/gone")
      assert msg =~ "removed"
    end

    test "returns error for 429", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn -> Plug.Conn.send_resp(conn, 429, "") end)
      assert {:error, msg} = UrlChecker.check("http://localhost:#{bypass.port}/rate")
      assert msg =~ "rate limited"
    end

    test "returns error for 4xx", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn -> Plug.Conn.send_resp(conn, 422, "") end)
      assert {:error, "HTTP 422"} = UrlChecker.check("http://localhost:#{bypass.port}/err")
    end

    test "returns error for 5xx", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn -> Plug.Conn.send_resp(conn, 500, "") end)
      assert {:error, msg} = UrlChecker.check("http://localhost:#{bypass.port}/err")
      assert msg =~ "server error"
    end

    test "returns error for unexpected status", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn -> Plug.Conn.send_resp(conn, 102, "") end)
      assert {:error, msg} = UrlChecker.check("http://localhost:#{bypass.port}/odd")
      assert msg =~ "unexpected"
    end

    test "returns error for connection failure" do
      assert {:error, msg} = UrlChecker.check("http://127.0.0.1:1/page")
      assert msg =~ "refused"
    end

    test "returns error for invalid URL" do
      assert {:error, "invalid URL"} = UrlChecker.check("not-a-url")
    end

    test "returns error for too many redirects", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "http://localhost:#{bypass.port}/loop")
        |> Plug.Conn.send_resp(301, "")
      end)

      assert {:error, "too many redirects"} = UrlChecker.check("http://localhost:#{bypass.port}/loop")
    end

    test "returns error for redirect with no Location header", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 301, "")
      end)

      assert {:error, "redirect with no Location header"} =
               UrlChecker.check("http://localhost:#{bypass.port}/page")
    end

    test "returns :html for 200 with no content-type header", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, "body")
      end)

      assert :html = UrlChecker.check("http://localhost:#{bypass.port}/page")
    end

    test "exercises resolve_url fallback for relative redirect location", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "/relative-dest")
        |> Plug.Conn.send_resp(301, "")
      end)

      # resolve_url/2 is called for the relative path but drops the port,
      # so the follow-up connection fails
      assert {:error, _} = UrlChecker.check("http://localhost:#{bypass.port}/page")
    end

    test "returns error for domain that does not resolve", _context do
      assert {:error, msg} = UrlChecker.check("http://this-host-does-not-exist.invalid/page")
      assert is_binary(msg)
    end
  end

  describe "check_all/1" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "returns results in same order as input", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/html")
        |> Plug.Conn.send_resp(200, "")
      end)

      urls = [
        "http://localhost:#{bypass.port}/a",
        "http://localhost:#{bypass.port}/b"
      ]

      results = UrlChecker.check_all(urls)
      assert length(results) == 2
      assert Enum.map(results, fn {url, _} -> url end) == urls
    end

    test "returns empty list for empty input" do
      assert [] = UrlChecker.check_all([])
    end

    test "handles mix of success and failure" do
      bypass = Bypass.open()

      Bypass.expect(bypass, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/html")
        |> Plug.Conn.send_resp(200, "")
      end)

      results =
        UrlChecker.check_all([
          "http://localhost:#{bypass.port}/ok",
          "http://127.0.0.1:1/fail"
        ])

      assert {_, :html} = List.keyfind(results, "http://localhost:#{bypass.port}/ok", 0)
      assert {_, {:error, _}} = List.keyfind(results, "http://127.0.0.1:1/fail", 0)
    end
  end
end
