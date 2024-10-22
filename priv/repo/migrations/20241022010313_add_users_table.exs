defmodule Flappy.Repo.Migrations.AddUsersTable do
  use Ecto.Migration

  def change do
    create table(:players) do
      add :name, :text
      add :score, :integer
      add :version, :integer
    end
  end
end
