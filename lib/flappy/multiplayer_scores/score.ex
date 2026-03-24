defmodule Flappy.MultiplayerScores.Score do
  @moduledoc false
  use Ecto.Schema
  alias Ecto.Changeset

  schema "multiplayer_scores" do
    field :name, :string
    field :survival_time_ms, :integer
    field :version, :integer

    timestamps()
  end

  def changeset(score, attrs) do
    score
    |> Changeset.cast(attrs, [:name, :survival_time_ms, :version])
    |> Changeset.validate_required([:name, :survival_time_ms])
  end
end
