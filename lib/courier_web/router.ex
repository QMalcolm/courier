defmodule CourierWeb.Router do
  use CourierWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CourierWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CourierWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/recipes", RecipeLive.Index, :index
    live "/recipes/new", RecipeLive.Index, :new
    live "/recipes/:id/edit", RecipeLive.Index, :edit

    live "/devices", DeviceLive.Index, :index
    live "/devices/new", DeviceLive.Index, :new
    live "/devices/:id/edit", DeviceLive.Index, :edit

    live "/subscriptions", SubscriptionLive.Index, :index
    live "/subscriptions/new", SubscriptionLive.Index, :new

    live "/logs", RunLive.Index, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", CourierWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:courier, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CourierWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
