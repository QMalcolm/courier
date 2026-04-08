defmodule Courier.Repo.Migrations.FixScheduleTimezones do
  use Ecto.Migration

  # Remaps friendly timezone display names (incorrectly stored as values due to
  # swapped tuple order in @timezones) to their IANA equivalents.
  @mappings [
    {"Eastern Time (US & Canada)", "America/New_York"},
    {"Central Time (US & Canada)", "America/Chicago"},
    {"Mountain Time (US & Canada)", "America/Denver"},
    {"Arizona (no DST)", "America/Phoenix"},
    {"Pacific Time (US & Canada)", "America/Los_Angeles"},
    {"Alaska", "America/Anchorage"},
    {"Hawaii", "Pacific/Honolulu"},
    {"Toronto", "America/Toronto"},
    {"Vancouver", "America/Vancouver"},
    {"Brasilia", "America/Sao_Paulo"},
    {"Mexico City", "America/Mexico_City"},
    {"London", "Europe/London"},
    {"Dublin", "Europe/Dublin"},
    {"Paris", "Europe/Paris"},
    {"Berlin", "Europe/Berlin"},
    {"Amsterdam", "Europe/Amsterdam"},
    {"Rome", "Europe/Rome"},
    {"Madrid", "Europe/Madrid"},
    {"Stockholm", "Europe/Stockholm"},
    {"Helsinki", "Europe/Helsinki"},
    {"Athens", "Europe/Athens"},
    {"Moscow", "Europe/Moscow"},
    {"Dubai", "Asia/Dubai"},
    {"Mumbai / Kolkata", "Asia/Kolkata"},
    {"Bangkok", "Asia/Bangkok"},
    {"Singapore", "Asia/Singapore"},
    {"Beijing / Shanghai", "Asia/Shanghai"},
    {"Tokyo", "Asia/Tokyo"},
    {"Seoul", "Asia/Seoul"},
    {"Sydney", "Australia/Sydney"},
    {"Melbourne", "Australia/Melbourne"},
    {"Perth", "Australia/Perth"},
    {"Auckland", "Pacific/Auckland"}
  ]

  def up do
    Enum.each(@mappings, fn {friendly, iana} ->
      execute("UPDATE schedules SET timezone = '#{iana}' WHERE timezone = '#{friendly}'")
    end)
  end

  def down do
    Enum.each(@mappings, fn {friendly, iana} ->
      execute("UPDATE schedules SET timezone = '#{friendly}' WHERE timezone = '#{iana}'")
    end)
  end
end
