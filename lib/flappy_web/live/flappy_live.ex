defmodule FlappyWeb.FlappyLive do
  @moduledoc """
  Flappy Phoenix - a Phoenix LiveView game. The main live view module.
  """
  use FlappyWeb, :live_view

  alias Flappy.FlappyEngine
  alias Flappy.Position

  def render(assigns) do
    ~H"""
    <div>
      <%!-- Game start container --%>
      <div
        :if={!@game_state.game_over && !@game_started}
        class="flex flex-col items-center justify-center h-screen"
      >
        <p class="text-white text-4xl my-11">Get ready to play Flappy Phoenix!</p>

        <div class="space-y-2">
          <p class="text-white text-2xl text-center">Don't let the 🐦‍🔥 fly off of the screen!</p>

          <p class="text-white text-2xl text-center">
            Oh, and don't let those other frameworks touch you!
          </p>

          <p class="text-white text-2xl text-center">
            Use WASD or the arrow keys (⬆️ ⬇️ ⬅️ and ➡️ ) to move up, down, left and right!
          </p>

          <p class="text-white text-2xl text-center">
            Press the space bar to activate your power-ups!
          </p>
        </div>

        <.simple_form for={@name_form} phx-submit="enter_name" class="flex flex-col items-center">
          <div class="relative">
            <.input
              type="text"
              value=""
              name="player_name"
              placeholder="Enter your name"
              class="rounded-l-md border-r-0 focus:outline-none focus:ring-2 focus:ring-blue-500"
              maxlength="10"
              required
            />
          </div>

          <.button type="submit" class="bg-blue-500 rounded">
            <p class="text-4xl text-white">Play</p>
          </.button>
        </.simple_form>
      </div>
      <%!-- Score container --%>
      <div :if={@game_state.game_over} class="flex flex-col items-center justify-center h-screen z-50">
        <p :if={@game_state.player.score != 69} class="text-white text-4xl z-50">
          YOU LOSE! I SAY GOOD DAY SIR!
        </p>
        <%!-- start Gavin's idea --%>
        <p :if={@game_state.player.score == 69} class="text-white text-4xl z-50">Nice!</p>
        <%!-- end Gavin's idea --%> <br />
        <p class="text-white text-4xl z-50">Your final score was <%= @game_state.player.score %></p>

        <.button phx-click="play_again" class="bg-blue-500 text-white px-4 py-2 rounded mt-4 z-50">
          <p class="p-4 text-4xl text-white">Play Again?</p>
        </.button>
      </div>

      <div
        id="score-container"
        class=" z-50 absolute top-0 left-0 ml-11 mt-11 bg-black rounded-md p-2"
      >
        <p class="text-white text-4xl">Score: <%= @game_state.player.score %></p>
      </div>
      <%!-- Game Area --%>
      <div id="game-area" phx-hook="ResizeHook" class="game-area w-screen h-screen -z-0">
        <%!-- Player --%>
        <div
          :if={@game_started && !@game_state.game_over}
          id="bird-container"
          phx-window-keydown="player_action"
          style={"position: absolute; left: #{elem(@game_state.player.position, 2)}%; top: #{elem(@game_state.player.position, 3)}%; "}
        >
          <img
            src={
              if @game_state.laser_allowed,
                do: ~p"/images/laser_phoenix.svg",
                else: @game_state.player.sprite.image
            }
            class={
              if @game_state.laser_allowed, do: "filter drop-shadow-[0_0_10px_rgba(255,0,0,0.7)]"
            }
          />
        </div>

        <div
          :if={@game_state.laser_beam && !@game_state.game_over}
          id="laser-beam"
          class="absolute bg-red-900 h-1 rounded-md"
          style={"left: #{Position.bird_x_eye_position(@game_state)}%; top: #{Position.bird_y_eye_position(@game_state)}%; width: #{100 - elem(@game_state.player.position, 2)}%;"}
        >
        </div>
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
      <div
        :if={@game_started && !@game_state.game_over && @is_mobile}
        class="fixed bottom-0 left-0 right-0 flex justify-center p-4 z-50"
      >
        <div class="grid grid-cols-3 gap-2">
          <button
            phx-click="player_action"
            phx-value-key="ArrowLeft"
            class="bg-blue-500 text-white p-2 rounded"
          >
            ⬅️
          </button>

          <div class="grid grid-rows-2 gap-2">
            <button
              phx-click="player_action"
              phx-value-key="ArrowUp"
              class="bg-blue-500 text-white p-2 rounded"
            >
              ⬆️
            </button>

            <button
              phx-click="player_action"
              phx-value-key="ArrowDown"
              class="bg-blue-500 text-white p-2 rounded"
            >
              ⬇️
            </button>
          </div>

          <button
            phx-click="player_action"
            phx-value-key="ArrowRight"
            class="bg-blue-500 text-white p-2 rounded"
          >
            ➡️
          </button>
        </div>

        <button
          phx-click="player_action"
          phx-value-key=" "
          class="bg-red-500 text-white p-2 rounded ml-4"
        >
          🔥
        </button>
      </div>
      <%!-- High Scores --%>
      <div class="fixed bottom-2 left-2 ml-2 w-60 z-50 rounded-lg p-3 text-sky-400">
        <h3 class="font-bold mb-2">High Scores</h3>
        <ul>
          <%= for {name, score} <- @current_high_scores do %>
            <li><%= name %>: <%= score %></li>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    game_height = get_connect_params(socket)["viewport_height"] || 760
    game_width = get_connect_params(socket)["viewport_width"] || 1440
    zoom_level = get_connect_params(socket)["zoom_level"] || 2
    is_mobile = game_width <= 450
    name_form = to_form(%{})

    Phoenix.PubSub.subscribe(Flappy.PubSub, "flappy:game_state:global")

    {:ok,
     socket
     |> assign(:messages, [])
     |> assign(:name_form, name_form)
     |> assign(:player_name, "")
     |> assign(:is_mobile, is_mobile)
     |> assign(:zoom_level, zoom_level)
     |> assign(:game_height, game_height)
     |> assign(:game_width, game_width)
     |> assign(:game_started, false)
     |> assign(:current_high_scores, [])
     |> assign(:game_state, %FlappyEngine{})
     |> assign(:game_height, game_height)}
  end

  def handle_event(
        "play_again",
        _,
        %{assigns: %{game_height: game_height, game_width: game_width, player_name: player_name, zoom_level: zoom_level}} =
          socket
      ) do
    {:ok, engine_pid} = FlappyEngine.start_engine(game_height, game_width, player_name, zoom_level)

    %{game_id: game_id, current_high_scores: current_high_scores} = game_state = FlappyEngine.get_game_state(engine_pid)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Flappy.PubSub, "flappy:game_state:#{game_id}")
    end

    {:noreply,
     socket
     |> assign(:game_state, game_state)
     |> assign(:current_high_scores, current_high_scores)
     |> assign(:engine_pid, engine_pid)}
  end

  def handle_event(
        "player_action",
        %{"key" => " "},
        %{assigns: %{engine_pid: engine_pid, game_state: %{game_over: false}}} = socket
      ) do
    if GenServer.whereis(engine_pid), do: FlappyEngine.fire_laser(engine_pid)

    {:noreply, socket}
  end

  def handle_event(
        "player_action",
        %{"key" => key},
        %{assigns: %{engine_pid: engine_pid, game_state: %{game_over: false}}} = socket
      ) do
    action =
      case String.downcase(key) do
        key when key in ["arrowup", "w"] -> &FlappyEngine.go_up/1
        key when key in ["arrowdown", "s"] -> &FlappyEngine.go_down/1
        key when key in ["arrowright", "d"] -> &FlappyEngine.go_right/1
        key when key in ["arrowleft", "a"] -> &FlappyEngine.go_left/1
        " " -> &FlappyEngine.fire_laser/1
        _key -> nil
      end

    if action && GenServer.whereis(engine_pid) do
      action.(engine_pid)
    end

    {:noreply, socket}
  end

  def handle_event("player_action", _, socket) do
    {:noreply, socket}
  end

  def handle_event("enter_name", %{"player_name" => player_name}, socket) do
    if String.length(player_name) in 1..10 do
      player_name
      |> HtmlSanitizeEx.strip_tags()
      |> start_game(socket)
    else
      {:noreply, put_flash(socket, :error, "Name must be between 1 and 10 characters")}
    end
  end

  def handle_event(
        "resize",
        %{"height" => game_height, "width" => game_width, "zoom" => zoom_level},
        %{assigns: %{engine_pid: engine_pid}} = socket
      ) do
    IO.inspect(zoom_level)
    IO.inspect(game_height)
    IO.inspect(game_width)

    if Process.alive?(engine_pid) do
      FlappyEngine.update_zoom(engine_pid, zoom_level)
    end

    {:noreply, socket}
  end

  def handle_event("resize", _params, socket) do
    {:noreply, socket}
  end

  def handle_info({:game_state_update, game_state}, %{assigns: %{engine_pid: engine_pid}} = socket) do
    if game_state.game_over do
      if Process.alive?(engine_pid) do
        FlappyEngine.stop_engine(engine_pid)
      end

      {:noreply, assign(socket, :game_state, %{game_state | game_over: true})}
    else
      {:noreply, assign(socket, :game_state, game_state)}
    end
  end

  def handle_info({:game_state_update, game_state}, socket) do
    {:noreply, assign(socket, game_state: game_state)}
  end

  def handle_info(
        {:high_score, %{player: %{name: player_name, score: score}}},
        %{assigns: %{messages: existing_messages, current_high_scores: current_high_scores}} = socket
      ) do
    new_high_scores =
      [{player_name, score} | current_high_scores]
      |> Enum.sort_by(fn {_, score} -> score end, :desc)
      |> Enum.take(5)

    nice_message = "NEW HIGH SCORE FROM #{player_name}, who got a whopping score of #{score}!"

    messages =
      Enum.take([nice_message | existing_messages], 3)

    message_to_display =
      messages
      |> Enum.join("<br>")
      |> Phoenix.HTML.raw()

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> assign(:current_high_scores, new_high_scores)
     |> put_flash(:score, message_to_display)}
  end

  def handle_info(
        {:new_score, %{player: %{name: player_name, score: score}}},
        %{assigns: %{messages: existing_messages}} = socket
      ) do
    mean_message =
      cond do
        score < 50 ->
          Enum.random([
            "They shouldn't quit their day job...",
            "Does something smell in here? Because they stunk!",
            "They must be playing with their eyes closed."
          ])

        score < 100 ->
          Enum.random([
            "They must be playing with their eyes closed.",
            "Were they trying to lose? Nailed it!",
            "They made ... a choice."
          ])

        true ->
          Enum.random([
            "I’ve seen rocks with better reflexes!",
            "A Phoenix should rise… not crash and burn!",
            "Not every bird is meant to soar, I guess."
          ])
      end

    messages =
      Enum.take(["#{player_name} just scored #{score}! #{mean_message}" | existing_messages], 3)

    message_to_display =
      messages
      |> Enum.join("<br>")
      |> Phoenix.HTML.raw()

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> put_flash(:score, message_to_display)}
  end

  defp start_game(
         player_name,
         %{assigns: %{game_height: game_height, game_width: game_width, zoom_level: zoom_level}} = socket
       ) do
    {:ok, engine_pid} = FlappyEngine.start_engine(game_height, game_width, player_name, zoom_level)
    %{game_id: game_id, current_high_scores: current_high_scores} = game_state = FlappyEngine.get_game_state(engine_pid)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Flappy.PubSub, "flappy:game_state:#{game_id}")
    end

    {:noreply,
     socket
     |> assign(:player_name, player_name)
     |> assign(:current_high_scores, current_high_scores)
     |> assign(:engine_pid, engine_pid)
     |> assign(:game_state, game_state)
     |> assign(:game_started, true)}
  end

  ### Used to generate z index between 1 and 50
  defp calculate_z_index("") do
    50
  end

  defp calculate_z_index(uuid) do
    uuid
    |> binary_part(0, 2)
    |> :binary.decode_unsigned()
    |> rem(50)
  end
end
