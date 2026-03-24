defmodule Flappy.Repo.Migrations.AddMultiplayerScoresTable do
  use Ecto.Migration

  def change do
    create table(:multiplayer_scores) do
      add :name, :string, null: false
      add :survival_time_ms, :integer, null: false

      timestamps()
    end

    create index(:multiplayer_scores, [:survival_time_ms])
  end
end
