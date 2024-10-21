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

      <div :if={@game_state.game_over} class="flex flex-col items-center justify-center h-screen z-50">
        <p :if={@game_state.score != 69} class="text-white text-4xl z-50">
          YOU LOSE! I SAY GOOD DAY SIR!
        </p>
        <%!-- start Gavin's idea --%>
        <p :if={@game_state.score == 69} class="text-white text-4xl z-50">Nice!</p>
        <%!-- end Gavin's idea --%> <br />
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
      <%!-- Game Area --%>
      <div id="game-area" class="game-area w-screen h-screen -z-0">
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
            class="absolute"
            style={"position: absolute; left: #{x_pos}%; top: #{y_pos}%;"}
          >
            <img src={enemy.sprite.image} />
          </div>
        <% end %>
        <%!-- Power Ups --%>
        <%= for %{position: {_, _, x_pos, y_pos}} = power_up <- @game_state.power_ups do %>
          <div
            id={"power-up-container-#{power_up.id}"}
            class="absolute power-up-glow"
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
    </div>
    """
  end

  def mount(_params, _session, socket) do
    game_height = get_connect_params(socket)["viewport_height"] || 0
    game_width = get_connect_params(socket)["viewport_width"] || 0
    is_mobile = game_width <= 450
    name_form = to_form(%{})

    Phoenix.PubSub.subscribe(Flappy.PubSub, "flappy:game_state:global")

    {:ok,
     socket
     |> assign(:messages, [])
     |> assign(:name_form, name_form)
     |> assign(:player_name, "")
     |> assign(:is_mobile, is_mobile)
     |> assign(:game_height, game_height)
     |> assign(:game_width, game_width)
     |> assign(:game_started, false)
     |> assign(:game_state, %FlappyEngine{})
     |> assign(:game_height, game_height)}
  end

  def handle_event("set_game_height", %{"height" => height}, socket) do
    {:noreply, assign(socket, game_height: height)}
  end

  def handle_event(
        "play_again",
        _,
        %{assigns: %{game_height: game_height, game_width: game_width, player_name: player_name}} = socket
      ) do
    {:ok, engine_pid} = FlappyEngine.start_engine(game_height, game_width, player_name)

    %{game_id: game_id} = game_state = FlappyEngine.get_game_state(engine_pid)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Flappy.PubSub, "flappy:game_state:#{game_id}")
    end

    {:noreply,
     socket
     |> assign(:game_state, game_state)
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
      case key do
        "ArrowUp" -> &FlappyEngine.go_up/1
        "W" -> &FlappyEngine.go_up/1
        "w" -> &FlappyEngine.go_up/1
        "ArrowDown" -> &FlappyEngine.go_down/1
        "S" -> &FlappyEngine.go_down/1
        "s" -> &FlappyEngine.go_down/1
        "ArrowRight" -> &FlappyEngine.go_right/1
        "D" -> &FlappyEngine.go_right/1
        "d" -> &FlappyEngine.go_right/1
        "ArrowLeft" -> &FlappyEngine.go_left/1
        "A" -> &FlappyEngine.go_left/1
        "a" -> &FlappyEngine.go_left/1
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

  def handle_event("enter_name", %{"player_name" => player_name}, socket) do
    if String.length(player_name) in 1..10 do
      player_name
      |> HtmlSanitizeEx.strip_tags()
      |> start_game(socket)
    else
      {:noreply, put_flash(socket, :error, "Name must be between 1 and 10 characters")}
    end
  end

  def handle_info({:game_state_update, game_state}, %{assigns: %{engine_pid: engine_pid}} = socket) do
    if game_state.game_over do
      FlappyEngine.stop_engine(engine_pid)

      {:noreply, assign(socket, :game_state, %{game_state | game_over: true})}
    else
      {:noreply, assign(socket, :game_state, game_state)}
    end
  end

  def handle_info({:game_state_update, game_state}, socket) do
    {:noreply, assign(socket, game_state: game_state)}
  end

  def handle_info(
        {:new_score, %{player: %{name: player_name}} = game_state},
        %{assigns: %{messages: existing_messages}} = socket
      ) do
    # Process.send_after(self(), {:clear_flash, message_id}, 5000)
    mean_message =
      cond do
        game_state.score < 50 ->
          Enum.random([
            "They shouldn't quit their day job...",
            "Does something smell in here? Because they stunk!",
            "They must be playing with their eyes closed."
          ])

        game_state.score < 100 ->
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
      Enum.take(["#{player_name} just scored #{game_state.score}! #{mean_message}" | existing_messages], 3)

    message_to_display =
      messages
      |> Enum.join("<br>")
      |> Phoenix.HTML.raw()

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> put_flash(:score, message_to_display)}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  defp start_game(player_name, %{assigns: %{game_height: game_height, game_width: game_width}} = socket) do
    {:ok, engine_pid} = FlappyEngine.start_engine(game_height, game_width, player_name)

    %{game_id: game_id} = game_state = FlappyEngine.get_game_state(engine_pid)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Flappy.PubSub, "flappy:game_state:#{game_id}")
    end

    {:noreply,
     socket
     |> assign(:player_name, player_name)
     |> assign(:engine_pid, engine_pid)
     |> assign(:game_state, game_state)
     |> assign(:game_started, true)}
  end
end
