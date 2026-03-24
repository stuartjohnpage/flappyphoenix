defmodule Flappy.Repo.Migrations.AddVersionToMultiplayerScores do
  use Ecto.Migration

  def change do
    alter table(:multiplayer_scores) do
      add :version, :integer
    end
  end
end
