defmodule FlappyWeb.FlappyLiveScores do
  @moduledoc false
  use FlappyWeb, :live_view

  alias Flappy.Players
  alias Flappy.MultiplayerScores

  def render(assigns) do
    ~H"""
    <div class="overflow-y-auto">
      <h1 class="text-cyan-100 text-9xl ">High Scores</h1>

      <div class="flex flex-row justify-between">
        <.back navigate={~p"/"}>
          <p class="text-lg text-cyan-100 hover:text-fuchsia-500">Back to Game</p>
        </.back>

        <div class="flex flex-row gap-4 items-end">
          <%!-- Mode tabs --%>
          <div class="flex gap-2">
            <button
              phx-click="set_mode"
              phx-value-mode="singleplayer"
              class={"px-4 py-2 rounded-t text-lg font-bold #{if @mode == "singleplayer", do: "bg-blue-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}
            >
              Singleplayer
            </button>
            <button
              phx-click="set_mode"
              phx-value-mode="multiplayer"
              class={"px-4 py-2 rounded-t text-lg font-bold #{if @mode == "multiplayer", do: "bg-purple-600 text-white", else: "bg-gray-700 text-gray-300 hover:bg-gray-600"}"}
            >
              Multiplayer
            </button>
          </div>

          <%!-- Version selector (singleplayer only) --%>
          <div :if={@mode == "singleplayer"}>
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
      </div>

      <div class="scrollable-content">
        <%!-- Singleplayer table --%>
        <div :if={@mode == "singleplayer"}>
          <.table id="players" rows={@players}>
            <:col :let={player} label="Name">
              <p class="text-cyan-100">{player.name}</p>
            </:col>

            <:col :let={player} label="Score">
              <p class="text-cyan-100">{player.score}</p>
            </:col>
          </.table>
        </div>

        <%!-- Multiplayer table --%>
        <div :if={@mode == "multiplayer"}>
          <.table id="mp-scores" rows={@mp_scores}>
            <:col :let={score} label="Name">
              <p class="text-cyan-100">{score.name}</p>
            </:col>

            <:col :let={score} label="Survival Time">
              <p class="text-cyan-100">{format_survival_time(score.survival_time_ms)}</p>
            </:col>
          </.table>
        </div>
      </div>
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
     |> assign(:version, version)
     |> assign(:mode, "singleplayer")
     |> assign(:players, [])
     |> assign(:mp_scores, [])}
  end

  def handle_event("set_mode", %{"mode" => mode}, socket) do
    {:noreply, push_patch(socket, to: ~p"/highscores?mode=#{mode}")}
  end

  def handle_event("version_selected", %{"version" => version}, socket) do
    {:noreply, push_patch(socket, to: ~p"/highscores?version=#{version}&mode=singleplayer")}
  end

  def handle_params(params, _uri, socket) do
    mode = params["mode"] || "singleplayer"
    version = params["version"] || Application.get_env(:flappy, :game_version, "1")

    socket = assign(socket, :mode, mode)
    socket = assign(socket, :version, version)

    socket =
      case mode do
        "multiplayer" ->
          mp_scores = MultiplayerScores.get_leaderboard(100)
          assign(socket, :mp_scores, mp_scores)

        _ ->
          players =
            100
            |> Players.get_current_high_scores(version)
            |> Enum.map(fn {name, score} -> %{name: name, score: score} end)

          assign(socket, :players, players)
      end

    {:noreply, socket}
  end

  defp format_survival_time(ms) when is_integer(ms) do
    total_seconds = div(ms, 1000)
    minutes = div(total_seconds, 60)
    secs = rem(total_seconds, 60)

    if minutes > 0 do
      "#{minutes}m #{String.pad_leading(Integer.to_string(secs), 2, "0")}s"
    else
      "#{secs}s"
    end
  end

  defp format_survival_time(_), do: "0s"
end
