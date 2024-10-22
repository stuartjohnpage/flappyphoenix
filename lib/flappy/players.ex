defmodule Flappy.Players do
  @moduledoc false
  import Ecto.Query

  alias Flappy.Players.Player
  alias Flappy.Repo

  @spec create_player!(map()) :: Player.t()
  def create_player!(attrs) do
    changeset = Player.changeset(%Player{}, attrs)
    Repo.insert!(changeset)
  end

  @spec update_player(Player.t(), map()) :: {:ok, Player.t() | :error, Ecto.Changeset.t()}
  def update_player(%Player{} = player, attrs) do
    changeset = Player.changeset(player, attrs)
    Repo.update(changeset)
  end

  def get_current_high_scores do
    current_game_version = Application.get_env(:flappy, :game_version, "1")

    Player
    |> where([p], p.version == ^current_game_version)
    |> select([p], {p.name, p.score})
    |> order_by(desc: :score)
    |> limit(5)
    |> Repo.all()
  end
end
