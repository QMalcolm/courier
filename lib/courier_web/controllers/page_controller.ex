defmodule CourierWeb.PageController do
  use CourierWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/recipes")
  end
end
