defmodule FlappyWeb.FlappyMultiplayerLive do
  @moduledoc """
  Multiplayer game LiveView. Connects to the global MultiplayerEngine.
  """
  use FlappyWeb, :live_view

  alias Flappy.MultiplayerEngine
  alias Flappy.GameState
  alias Flappy.Position

  def render(assigns) do
    ~H"""
    <div>
      <%!-- Name entry screen --%>
      <div
        :if={!@joined}
        class="flex flex-col items-center justify-center h-screen"
      >
        <p class="text-white text-4xl my-11">Multiplayer: King of the Hill</p>

        <div class="space-y-2">
          <p class="text-white text-2xl text-center">Compete in a shared world!</p>
          <p class="text-white text-xl text-center">Survive the longest to wear the crown</p>
        </div>

        <.simple_form for={@name_form} phx-submit="join_game" class="flex flex-col items-center">
          <div class="relative">
            <.input
              type="text"
              value=""
              name="player_name"
              placeholder="Enter your name"
              class="rounded-l-md border-r-0 focus:outline-none focus:ring-2 focus:ring-purple-500"
              maxlength="10"
              required
            />
          </div>

          <.button type="submit" class="bg-purple-600 rounded">
            <p class="text-4xl text-white">Join Game</p>
          </.button>
        </.simple_form>

        <.back navigate={~p"/"}>
          <p class="text-lg text-cyan-100 hover:text-fuchsia-500">Back to Singleplayer</p>
        </.back>
      </div>

      <%!-- Death screen overlay --%>
      <div
        :if={@joined && @dead}
        class="fixed inset-0 flex flex-col items-center justify-center z-50 bg-black bg-opacity-70"
      >
        <p class="text-red-400 text-5xl font-bold mb-4">YOU DIED</p>
        <p class="text-white text-2xl mb-2">
          Survival time: {format_survival_time(@my_survival_time)}
        </p>
        <p class="text-white text-xl mb-6">Score: {@my_score}</p>

        <.button phx-click="rejoin" class="bg-purple-600 text-white px-6 py-3 rounded text-2xl">
          Rejoin
        </.button>

        <div class="mt-4">
          <.back navigate={~p"/"}>
            <p class="text-lg text-cyan-100 hover:text-fuchsia-500">Back to Menu</p>
          </.back>
        </div>
      </div>

      <%!-- LAST BIRD STANDING banner --%>
      <div
        :if={@last_bird_standing}
        class="fixed top-1/4 left-0 right-0 z-50 flex justify-center pointer-events-none"
      >
        <div class="animate-pulse">
          <p class="text-yellow-300 text-6xl font-bold text-center"
             style="text-shadow: 0 0 20px rgba(234, 179, 8, 0.8), 0 0 40px rgba(234, 179, 8, 0.4);">
            LAST BIRD STANDING
          </p>
        </div>
      </div>

      <%!-- Multiplayer HUD --%>
      <div :if={@joined} class="fixed top-0 left-0 right-0 z-50 flex justify-between p-4 pointer-events-none">
        <%!-- Left: my score + survival time --%>
        <div class="bg-black bg-opacity-70 rounded-md p-3">
          <p class="text-white text-2xl">Score: {@my_score}</p>
          <p class="text-gray-300 text-lg">Time: {format_survival_time(@my_survival_time)}</p>
        </div>

        <%!-- Center: crown holder --%>
        <div class="bg-black bg-opacity-70 rounded-md p-3 text-center">
          <div :if={@crown_holder_name} class="flex items-center justify-center gap-2">
            <svg class="w-8 h-8 text-yellow-400" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z"/>
            </svg>
            <p class="text-yellow-300 text-2xl font-bold">{@crown_holder_name}</p>
          </div>
          <p :if={@crown_holder_name} class="text-gray-300 text-sm">
            {format_survival_time(@crown_holder_time)}
          </p>
          <p :if={!@crown_holder_name} class="text-gray-400 text-lg">No crown holder</p>
        </div>

        <%!-- Right: player count --%>
        <div class="bg-black bg-opacity-70 rounded-md p-3 text-right">
          <p class="text-white text-2xl">{@alive_count} alive</p>
          <p class="text-gray-300 text-lg">{@total_count} total</p>
        </div>
      </div>

      <%!-- Game Area --%>
      <div id="game-area" phx-hook="ResizeHook" class="game-area w-screen h-screen -z-0">
        <%!-- All players --%>
        <%= if @joined do %>
          <%= for {pid, player} <- @game_state.players, Map.get(player, :alive, true) do %>
            <div
              id={"player-#{pid}"}
              phx-window-keydown={if pid == @player_id, do: "player_action", else: nil}
              style={"position: absolute; left: #{elem(player.position, 2)}%; top: #{elem(player.position, 3)}%;"}
            >
              <%!-- Name tag --%>
              <div class="absolute -top-6 left-1/2 -translate-x-1/2 whitespace-nowrap">
                <span class={"text-sm font-bold px-1 rounded #{if pid == @player_id, do: "text-yellow-300 bg-black bg-opacity-60", else: "text-white bg-black bg-opacity-40"}"}>
                  {player.name}
                </span>
              </div>

              <%!-- Crown indicator --%>
              <div :if={pid == @crown_holder_id} class="absolute -top-10 left-1/2 -translate-x-1/2">
                <svg class="w-6 h-6 text-yellow-400 animate-bounce" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z"/>
                </svg>
              </div>

              <%!-- Bird sprite --%>
              <img
                src={player.sprite.image}
                class={bird_class(pid, @player_id, player)}
              />
            </div>

            <%!-- Laser beam for this player --%>
            <div
              :if={player.laser_beam}
              id={"laser-#{pid}"}
              class="absolute bg-red-900 h-1 rounded-md"
              style={"left: #{Position.bird_x_eye_position(player, @game_state.game_width)}%; top: #{Position.bird_y_eye_position(player, @game_state.game_height)}%; width: #{100 - elem(player.position, 2)}%;"}
            >
            </div>
          <% end %>
        <% end %>

        <%!-- Enemies --%>
        <%= for %{position: {_, _, x_pos, y_pos}} = enemy <- @game_state.enemies do %>
          <div
            id={"enemy-container-#{enemy.id}"}
            style={"position: absolute; left: #{x_pos}%; top: #{y_pos}%; z-index: #{calculate_z_index(enemy.id)};"}
          >
            <img src={enemy.sprite.image} />
          </div>
        <% end %>

        <%!-- Power Ups --%>
        <%= for %{position: {_, _, x_pos, y_pos}} = power_up <- @game_state.power_ups do %>
          <div
            id={"power-up-container-#{power_up.id}"}
            class="absolute"
            style={"position: absolute; left: #{x_pos}%; top: #{y_pos}%;"}
          >
            <img src={power_up.sprite.image} />
          </div>
        <% end %>

        <%!-- Explosions --%>
        <%= for %{position: {_, _, x_pos, y_pos}} = explosion <- @game_state.explosions do %>
          <div
            id={"explosion-container-#{explosion.id}"}
            class="explosion"
            style={"position: absolute; left: #{x_pos}%; top: #{y_pos}%;"}
          >
            <img src={explosion.sprite.image} />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    game_height = get_connect_params(socket)["viewport_height"] || 760
    game_width = get_connect_params(socket)["viewport_width"] || 1440
    zoom_level = get_connect_params(socket)["zoom_level"] || 2

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Flappy.PubSub, MultiplayerEngine.pubsub_topic())
    end

    {:ok,
     socket
     |> assign(:name_form, to_form(%{}))
     |> assign(:joined, false)
     |> assign(:dead, false)
     |> assign(:player_id, nil)
     |> assign(:player_name, "")
     |> assign(:game_state, %GameState{})
     |> assign(:my_score, 0)
     |> assign(:my_survival_time, 0)
     |> assign(:crown_holder_id, nil)
     |> assign(:crown_holder_name, nil)
     |> assign(:crown_holder_time, 0)
     |> assign(:alive_count, 0)
     |> assign(:total_count, 0)
     |> assign(:last_bird_standing, false)
     |> assign(:game_height, game_height)
     |> assign(:game_width, game_width)
     |> assign(:zoom_level, zoom_level)}
  end

  def handle_params(%{"name" => name}, _uri, %{assigns: %{joined: false}} = socket) when byte_size(name) > 0 do
    {:noreply, join_game(name, socket)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def terminate(_reason, %{assigns: %{joined: true, player_id: player_id}} = _socket) do
    MultiplayerEngine.leave(player_id)
    :ok
  end

  def terminate(_reason, _socket), do: :ok

  def handle_event("join_game", %{"player_name" => player_name}, socket) do
    if String.length(player_name) in 1..10 do
      {:noreply, join_game(player_name, socket)}
    else
      {:noreply, put_flash(socket, :error, "Name must be between 1 and 10 characters")}
    end
  end

  def handle_event("rejoin", _, %{assigns: %{player_name: player_name}} = socket) do
    {:noreply, join_game(player_name, socket)}
  end

  def handle_event(
        "player_action",
        %{"key" => key},
        %{assigns: %{player_id: player_id, dead: false}} = socket
      ) do
    action =
      case String.downcase(key) do
        key when key in ["arrowup", "w"] -> :go_up
        key when key in ["arrowdown", "s"] -> :go_down
        key when key in ["arrowright", "d"] -> :go_right
        key when key in ["arrowleft", "a"] -> :go_left
        " " -> :fire_laser
        _key -> nil
      end

    if action do
      MultiplayerEngine.player_input(player_id, action)
    end

    {:noreply, socket}
  end

  def handle_event("player_action", _, socket), do: {:noreply, socket}

  def handle_event("resize", %{"height" => h, "width" => w, "zoom" => z}, socket) do
    MultiplayerEngine.update_viewport(z, w, h)
    {:noreply, assign(socket, game_width: w, game_height: h, zoom_level: z)}
  end

  def handle_info({:multiplayer_state, game_state}, %{assigns: assigns} = socket) do
    player_id = assigns.player_id
    my_player = game_state.players[player_id]

    # Check if I just died
    just_died = my_player != nil && !Map.get(my_player, :alive, true) && !assigns.dead

    # Derive HUD data
    crown_id = GameState.crown_holder(game_state)
    crown_player = if crown_id, do: game_state.players[crown_id]

    alive_players = Enum.filter(game_state.players, fn {_id, p} -> Map.get(p, :alive, true) end)

    is_last_bird =
      my_player != nil &&
        Map.get(my_player, :alive, true) &&
        GameState.last_bird_standing?(game_state)

    socket =
      socket
      |> assign(:game_state, game_state)
      |> assign(:my_score, if(my_player, do: my_player.score, else: assigns.my_score))
      |> assign(:my_survival_time, if(my_player, do: Map.get(my_player, :survival_time, 0), else: assigns.my_survival_time))
      |> assign(:crown_holder_id, crown_id)
      |> assign(:crown_holder_name, if(crown_player, do: crown_player.name, else: nil))
      |> assign(:crown_holder_time, if(crown_player, do: Map.get(crown_player, :survival_time, 0), else: 0))
      |> assign(:alive_count, length(alive_players))
      |> assign(:total_count, map_size(game_state.players))
      |> assign(:last_bird_standing, is_last_bird)

    socket = if just_died, do: assign(socket, :dead, true), else: socket

    {:noreply, socket}
  end

  # --- Helpers ---

  defp bird_class(pid, my_id, player) do
    base = ""

    # Golden highlight for self
    self_glow =
      if pid == my_id,
        do: "filter drop-shadow-[0_0_15px_rgba(255,215,0,0.8)]",
        else: ""

    # Laser glow
    laser_glow =
      if player.laser_allowed,
        do: "filter drop-shadow-[0_5px_10px_rgba(255,0,0,0.7)]",
        else: ""

    # Self highlight takes priority, laser glow as fallback
    cond do
      pid == my_id && player.laser_allowed ->
        "filter drop-shadow-[0_0_15px_rgba(255,215,0,0.8)] drop-shadow-[0_5px_10px_rgba(255,0,0,0.7)]"

      pid == my_id ->
        self_glow

      player.laser_allowed ->
        laser_glow

      true ->
        base
    end
  end

  defp format_survival_time(ticks) when is_integer(ticks) do
    seconds = ticks
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)

    if minutes > 0 do
      "#{minutes}m #{String.pad_leading(Integer.to_string(secs), 2, "0")}s"
    else
      "#{secs}s"
    end
  end

  defp format_survival_time(_), do: "0s"

  defp calculate_z_index(""), do: 50

  defp calculate_z_index(uuid) do
    uuid
    |> binary_part(0, 2)
    |> :binary.decode_unsigned()
    |> rem(50)
  end

  defp join_game(player_name, %{assigns: assigns} = socket) do
    player_name =
      player_name
      |> HtmlSanitizeEx.strip_tags()
      |> sanitize_player_name()

    player_id = Ecto.UUID.generate()
    :ok = MultiplayerEngine.join(player_id, player_name)

    # Update the shared game dimensions to match this player's viewport
    MultiplayerEngine.update_viewport(assigns.zoom_level, assigns.game_width, assigns.game_height)

    socket
    |> assign(:joined, true)
    |> assign(:dead, false)
    |> assign(:player_id, player_id)
    |> assign(:player_name, player_name)
    |> assign(:last_bird_standing, false)
  end

  defp sanitize_player_name(player_name) do
    config = Expletive.configure(blacklist: Expletive.Blacklist.english())

    player_name =
      player_name
      |> HtmlSanitizeEx.strip_tags()
      |> Expletive.sanitize(config)

    if player_name |> String.replace(" ", "") |> Expletive.profane?(config) do
      "Anonymous"
    else
      player_name
    end
  end
end
