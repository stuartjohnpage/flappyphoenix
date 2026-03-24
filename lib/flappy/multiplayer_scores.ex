defmodule Flappy.MultiplayerScores do
  @moduledoc """
  Context for multiplayer leaderboard queries.
  """
  import Ecto.Query

  alias Flappy.MultiplayerScores.Score
  alias Flappy.Repo

  def save_score!(name, survival_time_ms) do
    version = get_version()

    %Score{}
    |> Score.changeset(%{name: name, survival_time_ms: survival_time_ms, version: version})
    |> Repo.insert!()
  end

  def get_leaderboard(limit, version) do
    version = to_integer(version)

    Score
    |> where([s], s.version == ^version or is_nil(s.version))
    |> select([s], %{name: s.name, survival_time_ms: s.survival_time_ms})
    |> order_by(desc: :survival_time_ms)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_leaderboard(limit) do
    get_leaderboard(limit, get_version())
  end

  defp get_version do
    to_integer(Application.get_env(:flappy, :game_version, "1"))
  end

  defp to_integer(v) when is_integer(v), do: v
  defp to_integer(v) when is_binary(v), do: String.to_integer(v)
end
