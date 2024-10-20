# Flappy Phoenix

Welcome to **Flappy Phoenix**, a game built using Phoenix LiveView. In this game, you control a little phoenix bird (the same one from the Phoenix Framework logo) and your goal is to avoid other framework logos while keeping the bird within the screen bounds. The game gets progressively harder as you play, so stay sharp!

# Note: 

When I first started writing this, I had no idea https://github.com/moomerman/flappy-phoenix existed: a previous project which implements LiveView to create a faithful Flappy bird clone. You should check this project out if you are interested: it's pretty cool! 

## Table of Contents

- [Gameplay](#gameplay)
- [Installation](#installation)
- [Usage](#usage)
- [Credits](#credits)

## Gameplay

- **Objective**: Avoid touching any of the framework logos that appear as enemies and keep the bird within the screen bounds.
- **Controls**: Use the arrow keys to move up, down, left, and right.

  ```
  ⬆️  - Move Up
  ⬇️  - Move Down
  ⬅️  - Move Left
  ➡️  - Move Right
  ```

- **Score**: The score increases the longer you survive.

## Installation

### Prerequisites

To run this project, you will need:

- Elixir
- Phoenix Framework

### Steps

1. Clone the repository:
   ```bash
   git clone <repository_url>
   cd flappy_phoenix
   ```

2. Install dependencies:
   ```bash
   mix deps.get
   ```

3. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

4. Open your web browser and navigate to `http://localhost:4000` to play the game.

## Usage

### Starting the Game

When you first load the game, you will see a welcome screen. Click the "Play" button to begin the game.

### In-Game

Use the arrow keys to navigate your phoenix and avoid the other framework logos. If the phoenix touches an enemy logo or flies off the screen, the game will end, and your final score will be displayed.

### Restarting the Game

Click the "Play Again?" button to restart the game after it ends.

## Credits

- Game developed using Elixir and the Phoenix Framework.
- Inspired by the classic "Flappy Bird" game.
- Competing framework logos: Angular, Django, JQuery, Laravel, Ember, React, Vue, Node, and Ruby on Rails.

Enjoy the game and good luck flying your phoenix! 🐦‍🔥

If you encounter any issues or have suggestions, feel free to contribute or open an issue in the repository.

---

Stuart Page
