defmodule FlappyWeb.FlappyLiveScores do
  @moduledoc false
  use FlappyWeb, :live_view

  alias Flappy.Players

  def render(assigns) do
    ~H"""
    <h1 class="text-cyan-100 text-9xl">High Scores</h1>
    <div class="flex flex-row justify-between">
      <.back navigate={~p"/"}>
        <p class="text-lg text-cyan-100 hover:text-fuchsia-500">Back to Game</p>
      </.back>
      <div>
        <h1 class="text-cyan-100">Version</h1>
        <.simple_form for={@form} phx-change="version_selected">
          <.input
            class="w-2/12"
            type="select"
            name="version"
            options={@available_versions}
            value={@version}
          />
        </.simple_form>
      </div>
    </div>
    <div class="overflow-clip">
      <.table id="players" rows={@players}>
        <:col :let={player} label="Name">
          <p class="text-cyan-100"><%= player.name %></p>
        </:col>
        <:col :let={player} label="Score">
          <p class="text-cyan-100"><%= player.score %></p>
        </:col>
      </.table>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    available_versions = Players.get_available_versions()
    version = Application.get_env(:flappy, :game_version, "1")

    {:ok,
     socket
     |> assign(:form, to_form(%{}))
     |> assign(:available_versions, available_versions)
     |> assign(:version, version)}
  end

  def handle_event("version_selected", %{"version" => version}, socket) do
    IO.inspect("here mate")
    {:noreply, push_patch(socket, to: ~p"/highscores?version=#{version}")}
  end

  def handle_params(%{"version" => version}, _uri, socket) do
    players =
      100
      |> Players.get_current_high_scores(version)
      |> Enum.map(fn {name, score} -> %{name: name, score: score} end)

    {:noreply, socket |> assign(:players, players) |> assign(:version, version)}
  end

  def handle_params(_params, _uri, socket) do
    version = Application.get_env(:flappy, :game_version, "1")

    players =
      100
      |> Players.get_current_high_scores(version)
      |> Enum.map(fn {name, score} -> %{name: name, score: score} end)

    {:noreply, socket |> assign(:players, players) |> assign(:version, version)}
  end
end
