defmodule Courier.Repo.Migrations.ResetRecipeSourcesToYaml do
  use Ecto.Migration

  # Recipe source format changed from raw Python to YAML.
  # Reset any existing records to the default YAML template so they
  # pass validation and prompt the user to re-enter their feeds.
  def up do
    execute(
      "UPDATE recipes SET source = " <>
        "'feeds:' || char(10) || " <>
        "'  - name: Feed Name' || char(10) || " <>
        "'    url: https://example.com/rss' || char(10)"
    )
  end

  def down, do: :ok
end
