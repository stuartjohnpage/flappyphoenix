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

  def get_available_versions do
    Player
    |> select([p], {p.version})
    |> Repo.all()
    |> Enum.flat_map(fn {version} -> if is_nil(version), do: [], else: [version] end)
    |> Enum.uniq()
    |> Enum.sort(:desc)
  end

  def get_current_high_scores(limit, current_game_version) do
    Player
    |> where([p], p.version == ^current_game_version)
    |> select([p], {p.name, p.score})
    |> order_by(desc: :score)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_sprite(:laser_invincibility) do
    %{image: "/images/laser_invincible.svg", size: {128, 89}, name: :laser_phoenix}
  end

  def get_sprite(:invincibility) do
    %{image: "/images/invincible.svg", size: {128, 89}, name: :laser_phoenix}
  end

  def get_sprite(:laser) do
    %{image: "/images/laser_phoenix.svg", size: {128, 89}, name: :laser_phoenix}
  end

  def get_sprite(:test) do
    %{image: "/images/test_blue.svg", size: {100, 100}, name: :test}
  end

  def get_sprite do
    %{image: "/images/flipped_phoenix.svg", size: {128, 89}, name: :phoenix}
  end
end
