defmodule CourierWeb.PageControllerTest do
  use CourierWeb.ConnCase

  test "GET / redirects to recipes", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/recipes"
  end
end
