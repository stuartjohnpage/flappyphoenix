defmodule Flappy.MultiplayerScores do
  @moduledoc """
  Context for multiplayer leaderboard queries.
  """
  import Ecto.Query

  alias Flappy.MultiplayerScores.Score
  alias Flappy.Repo

  def save_score!(name, survival_time_ms) do
    %Score{}
    |> Score.changeset(%{name: name, survival_time_ms: survival_time_ms})
    |> Repo.insert!()
  end

  def get_leaderboard(limit \\ 100) do
    Score
    |> select([s], %{name: s.name, survival_time_ms: s.survival_time_ms})
    |> order_by(desc: :survival_time_ms)
    |> limit(^limit)
    |> Repo.all()
  end
end
