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
      <div
        :if={!@game_state.game_over && !@game_started}
        class="flex flex-col items-center justify-center h-screen"
      >
        <p class="text-white text-4xl">Get ready to play Flappy Phoenix!</p>
        <br />
        <p class="text-white text-2xl">Don't let the 🐦‍🔥 fly off of the screen!</p>
        <br />
        <p class="text-white text-2xl">Oh, and don't let those other frameworks touch you!</p>
        <br />
        <p class="text-white text-2xl">
          Use the arrow keys (⬆️ ⬇️ ⬅️ and ➡️ ) to move up, down, left and right!
        </p>
        <br />
        <p class="text-white text-2xl">
          Press the space bar to activate your power-ups!
        </p>
        <br />
        <p class="text-white text-2xl">👀 Good luck!</p>
        <.button phx-click="start_game" class="bg-blue-500 rounded mt-10">
          <p class="p-4 text-4xl text-white">Play</p>
        </.button>
      </div>
      <div :if={@game_state.game_over} class="flex flex-col items-center justify-center h-screen z-50">
        <p :if={@game_state.score != 69} class="text-white text-4xl z-50">
          YOU LOSE! I SAY GOOD DAY SIR!
        </p>
        <%!-- start Gavin's idea --%>
        <p :if={@game_state.score == 69} class="text-white text-4xl z-50">Nice!</p>
        <%!-- end Gavin's idea --%>

        <br />
        <p class="text-white text-4xl z-50">Your final score was <%= @game_state.score %></p>
        <.button phx-click="play_again" class="bg-blue-500 text-white px-4 py-2 rounded mt-4 z-50">
          <p class="p-4 text-4xl text-white">Play Again?</p>
        </.button>
      </div>
      <div
        id="score-container"
        class=" z-50 absolute top-0 left-0 ml-11 mt-11 bg-black rounded-md p-2"
      >
        <p class="text-white text-4xl">Score: <%= @game_state.score %></p>
      </div>
      <div id="game-area" class="game-area w-screen h-screen -z-0">
        <div
          :if={@game_started && !@game_state.game_over}
          id="bird-container"
          phx-window-keydown="player_action"
          style={"position: absolute; left: #{@bird_x_position_percentage}%; top: #{@bird_y_position_percentage}%; "}
        >
          <img
            src={
              if @game_state.laser_allowed,
                do: ~p"/images/laser_phoenix.svg",
                else: ~p"/images/flipped_phoenix.svg"
            }
            class={
              if @game_state.laser_allowed, do: "filter drop-shadow-[0_0_10px_rgba(255,0,0,0.7)]"
            }
          />
          <%!-- <img src={~p"/images/test_blue.svg"} /> --%>
        </div>

        <div
          :if={@game_state.laser_beam && !@game_state.game_over}
          id="laser-beam"
          class="absolute bg-red-900 h-1 rounded-md"
          style={"left: #{Position.bird_x_eye_position(@bird_x_position_percentage, @game_state)}%; top: #{Position.bird_y_eye_position(@bird_y_position_percentage, @game_state)}%; width: #{100 - @bird_x_position_percentage}%;"}
        >
        </div>

        <%= for %{position: {_, _, x_pos, y_pos}} = enemy <- @game_state.enemies do %>
          <div
            id={"enemy-container-#{enemy.id}"}
            class="absolute"
            style={"position: absolute; left: #{x_pos}%; top: #{y_pos}%;"}
          >
            <img src={enemy.sprite.image} />
          </div>
        <% end %>

        <%= for %{position: {_, _, x_pos, y_pos}} = power_up <- @game_state.power_ups do %>
          <div
            id={"power-up-container-#{power_up.id}"}
            class="absolute power-up-glow"
            style={"position: absolute; left: #{x_pos}%; top: #{y_pos}%;"}
          >
            <img src={power_up.sprite.image} />
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
    </div>
    """
  end

  def mount(_params, _session, socket) do
    game_height = get_connect_params(socket)["viewport_height"] || 0
    game_width = get_connect_params(socket)["viewport_width"] || 0
    is_mobile = game_width <= 450

    {:ok,
     socket
     |> assign(:is_mobile, is_mobile)
     |> assign(:bird_x_position_percentage, 0)
     |> assign(:bird_y_position_percentage, 50)
     |> assign(:game_height, game_height)
     |> assign(:game_width, game_width)
     |> assign(:game_started, false)
     |> assign(:game_state, %FlappyEngine{})
     |> assign(:game_height, game_height)}
  end

  def handle_event("start_game", _, %{assigns: %{game_height: game_height, game_width: game_width}} = socket) do
    {:ok, engine_pid} = FlappyEngine.start_engine(game_height, game_width)

    %{
      player: %{position: player_position},
      game_id: game_id
    } = game_state = FlappyEngine.get_game_state(engine_pid)

    {_, _, player_percentage_x, player_percentage_y} = player_position

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Flappy.PubSub, "flappy:game_state:#{game_id}")
    end

    {:noreply,
     socket
     |> assign(:engine_pid, engine_pid)
     |> assign(:bird_x_position_percentage, player_percentage_x)
     |> assign(:bird_y_position_percentage, player_percentage_y)
     |> assign(:game_state, game_state)
     |> assign(:game_started, true)}
  end

  def handle_event("set_game_height", %{"height" => height}, socket) do
    {:noreply, assign(socket, game_height: height)}
  end

  def handle_event("play_again", _, %{assigns: %{game_height: game_height, game_width: game_width}} = socket) do
    {:ok, engine_pid} = FlappyEngine.start_engine(game_height, game_width)

    %{
      player: %{position: player_position},
      game_id: game_id
    } =
      game_state =
      FlappyEngine.get_game_state(engine_pid)

    {_, _, player_percentage_x, player_percentage_y} = player_position

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Flappy.PubSub, "flappy:game_state:#{game_id}")
    end

    {:noreply,
     socket
     |> assign(:game_state, game_state)
     |> assign(:engine_pid, engine_pid)
     |> assign(:bird_x_position_percentage, player_percentage_x)
     |> assign(:bird_y_position_percentage, player_percentage_y)}
  end

  def handle_event(
        "player_action",
        %{"key" => "ArrowUp"},
        %{assigns: %{engine_pid: engine_pid, game_state: %{game_over: false}}} = socket
      ) do
    if GenServer.whereis(engine_pid), do: FlappyEngine.go_up(engine_pid)

    {:noreply, socket}
  end

  def handle_event("go_up", _, %{assigns: %{engine_pid: engine_pid, game_state: %{game_over: false}}} = socket) do
    if GenServer.whereis(engine_pid), do: FlappyEngine.go_up(engine_pid)

    {:noreply, socket}
  end

  def handle_event(
        "player_action",
        %{"key" => "ArrowDown"},
        %{assigns: %{engine_pid: engine_pid, game_state: %{game_over: false}}} = socket
      ) do
    if GenServer.whereis(engine_pid), do: FlappyEngine.go_down(engine_pid)

    {:noreply, socket}
  end

  def handle_event(
        "player_action",
        %{"key" => "ArrowRight"},
        %{assigns: %{engine_pid: engine_pid, game_state: %{game_over: false}}} = socket
      ) do
    if GenServer.whereis(engine_pid), do: FlappyEngine.go_right(engine_pid)

    {:noreply, socket}
  end

  def handle_event(
        "player_action",
        %{"key" => "ArrowLeft"},
        %{assigns: %{engine_pid: engine_pid, game_state: %{game_over: false}}} = socket
      ) do
    if GenServer.whereis(engine_pid), do: FlappyEngine.go_left(engine_pid)

    {:noreply, socket}
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
      case key do
        "ArrowUp" -> &FlappyEngine.go_up/1
        "ArrowDown" -> &FlappyEngine.go_down/1
        "ArrowRight" -> &FlappyEngine.go_right/1
        "ArrowLeft" -> &FlappyEngine.go_left/1
        " " -> &FlappyEngine.fire_laser/1
        _ -> nil
      end

    if action && GenServer.whereis(engine_pid) do
      action.(engine_pid)
    end

    {:noreply, socket}
  end

  def handle_event("player_action", _, socket) do
    {:noreply, socket}
  end

  def handle_info({:game_state_update, game_state}, %{assigns: %{engine_pid: engine_pid}} = socket) do
    %{
      player: %{position: player_position}
    } = game_state

    {_, _, player_percentage_x, player_percentage_y} = player_position

    if game_state.game_over do
      FlappyEngine.stop_engine(engine_pid)

      {:noreply,
       socket
       |> assign(:bird_x_position_percentage, player_percentage_x)
       |> assign(:bird_y_position_percentage, player_percentage_y)
       |> assign(:game_state, %{game_state | game_over: true})}
    else
      {:noreply,
       socket
       |> assign(:game_state, game_state)
       |> assign(:bird_x_position_percentage, player_percentage_x)
       |> assign(:bird_y_position_percentage, player_percentage_y)}
    end
  end

  def handle_info({:game_state_update, game_state}, socket) do
    {:noreply, assign(socket, game_state: game_state)}
  end
end
