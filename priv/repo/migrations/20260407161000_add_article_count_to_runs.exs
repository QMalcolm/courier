defmodule Courier.Repo.Migrations.AddArticleCountToRuns do
  use Ecto.Migration

  def change do
    alter table(:runs) do
      add :article_count, :integer
    end
  end
end
