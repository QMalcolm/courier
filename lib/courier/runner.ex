defmodule Courier.Runner do
  @moduledoc """
  Executes a delivery: converts a recipe to epub via Calibre, optionally
  archives it to a Calibre library, and sends it to a device via SMTP.

  Each delivery runs in a supervised Task. Progress is broadcast over
  PubSub on the "runs" topic so the Logs LiveView can update live.

  Configuration via environment variables:
    COURIER_CALIBRE_PATH      Path to Calibre binaries (default: /opt/calibre)
    COURIER_CALIBRE_LIBRARY   Path to Calibre library for archiving (optional)
    COURIER_SMTP_FROM         Sender email address
    COURIER_SMTP_USERNAME     SMTP username
    COURIER_SMTP_PASSWORD     SMTP password
    COURIER_SMTP_RELAY        SMTP relay host (default: smtp.gmail.com)
    COURIER_SMTP_PORT         SMTP port (default: 587)
    COURIER_SMTP_ENCRYPTION   TLS or STARTTLS (default: TLS)
  """

  require Logger

  alias Courier.Library.Recipe
  alias Courier.Runs
  alias Courier.Subscriptions.Subscription

  @doc """
  Runs deliveries for enabled subscriptions whose recipe is associated with
  the given schedule. Called by Quantum on schedule.
  """
  def run_for_schedule(schedule_id) do
    recipe_ids = Courier.Schedules.list_recipe_ids_for_schedule(schedule_id)

    Courier.Subscriptions.list_enabled_subscriptions_for_recipes(recipe_ids)
    |> Enum.each(&run/1)
  end

  @doc """
  Runs deliveries for all enabled subscriptions for a specific recipe.
  Used for manual one-off runs.
  """
  def run_recipe(recipe_id) do
    Courier.Subscriptions.list_enabled_subscriptions_for_recipe(recipe_id)
    |> Enum.each(&run/1)
  end

  @doc "Starts an async delivery for the given subscription."
  def run(%Subscription{recipe: recipe, device: device} = _subscription) do
    Task.Supervisor.start_child(Courier.TaskSupervisor, fn ->
      execute(recipe, device)
    end)
  end

  defp execute(recipe, device) do
    Logger.info("[Runner] Starting: recipe=#{recipe.slug} device=#{device.email}")

    {:ok, run} =
      Runs.create_run(%{
        recipe_id: recipe.id,
        device_id: device.id,
        status: "running",
        started_at: DateTime.utc_now()
      })

    broadcast({:run_updated, run})

    {status, log} = deliver(recipe, device)

    {:ok, finished_run} =
      Runs.update_run(run, %{
        status: status,
        finished_at: DateTime.utc_now(),
        log_output: log
      })

    Logger.info("[Runner] Finished: recipe=#{recipe.slug} status=#{status}")
    broadcast({:run_updated, finished_run})
  end

  defp deliver(recipe, device) do
    work_dir =
      Path.join(System.tmp_dir!(), "courier_#{recipe.slug}_#{System.unique_integer([:positive])}")

    File.mkdir_p!(work_dir)
    recipe_file = Path.join(work_dir, "recipe.recipe")
    epub_file = Path.join(work_dir, "output.epub")
    File.write!(recipe_file, Recipe.to_python(recipe))

    {status, log} = run_steps(recipe_file, epub_file, recipe, device)

    File.rm_rf!(work_dir)
    {status, log}
  end

  defp run_steps(recipe_file, epub_file, recipe, device) do
    case run_convert(recipe_file, epub_file, recipe) do
      {:ok, convert_log} ->
        archive_log = maybe_archive(epub_file)

        case run_smtp(epub_file, recipe, device) do
          {:ok, smtp_log} -> {"success", convert_log <> archive_log <> smtp_log}
          {:error, smtp_log} -> {"failure", convert_log <> archive_log <> smtp_log}
        end

      {:error, convert_log} ->
        {"failure", convert_log}
    end
  end

  defp run_convert(recipe_file, epub_file, _recipe) do
    cmd(calibre_bin("ebook-convert"), [recipe_file, epub_file], "ebook-convert")
  end

  defp maybe_archive(epub_file) do
    case System.get_env("COURIER_CALIBRE_LIBRARY") do
      nil ->
        ""

      library_path ->
        case cmd(calibre_bin("calibredb"), ["add", epub_file, "--library-path", library_path], "calibredb add") do
          {:ok, log} -> log
          {:error, log} -> log
        end
    end
  end

  defp run_smtp(epub_file, recipe, device) do
    %{
      from: from,
      username: username,
      password: password,
      relay: relay,
      port: port,
      encryption: encryption
    } = smtp_config()

    subject = "#{recipe.name} — #{Date.utc_today()}"

    args = [
      "--username", username,
      "--password", password,
      "--relay", relay,
      "--port", port,
      "--encryption", encryption,
      "--subject", subject,
      "--attachment", epub_file,
      from,
      device.email,
      "Delivered by Courier"
    ]

    cmd(calibre_bin("calibre-smtp"), args, "calibre-smtp")
  end

  defp cmd(bin, args, label) do
    header = "=== #{label} ===\n"

    case System.cmd(bin, args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, header <> output <> "\n"}
      {output, code} -> {:error, header <> output <> "\nExited with code #{code}\n"}
    end
  rescue
    e -> {:error, "=== #{label} ===\nFailed to start process: #{Exception.message(e)}\n"}
  end

  defp calibre_bin(name) do
    Path.join(System.get_env("COURIER_CALIBRE_PATH", "/opt/calibre"), name)
  end

  defp smtp_config do
    %{
      from: System.get_env("COURIER_SMTP_FROM", ""),
      username: System.get_env("COURIER_SMTP_USERNAME", ""),
      password: System.get_env("COURIER_SMTP_PASSWORD", ""),
      relay: System.get_env("COURIER_SMTP_RELAY", "smtp.gmail.com"),
      port: System.get_env("COURIER_SMTP_PORT", "587"),
      encryption: System.get_env("COURIER_SMTP_ENCRYPTION", "TLS")
    }
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(Courier.PubSub, "runs", message)
  end
end
