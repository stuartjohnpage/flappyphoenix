# Flappy Phoenix

Welcome to **Flappy Phoenix**, a game built using Phoenix LiveView. In this game, you control a little phoenix bird (the same one from the Phoenix Framework logo) and your goal is to avoid other framework logos while keeping the bird within the screen bounds. The game gets progressively harder as you play, so stay sharp!

# Note: 

This project should not be confused with [Flappy Phoenix](https://github.com/moomerman/flappy-phoenix). When I first thought up the concept and title for this game, I had no idea that that project existed. It's a pretty old project that implements an early version LiveView to create a faithful Flappy bird clone. You should check it out if you are interested: it's pretty cool! 

## Table of Contents

- [Gameplay](#gameplay)
- [Installation](#installation)
- [Usage](#usage)
- [Credits](#credits)

## Gameplay

- **Objective**: Avoid touching any of the framework logos that appear as enemies and keep the bird within the screen bounds.
- **Controls**: Use the arrow keys or WASD to move up, down, left, and right.
- **Score**: The score increases the longer you survive, and the more enemies you destroy.
- **Power-ups**: Collect special items to gain temporary advantages:
- `REACT-ive armour`: Temporary invincibility, which destroys enemies you come into contact with.
- `The ELIXIR of LASER`: Press the space bar to fire a laser which destroys all enemies in it's path.
- `THE OBANomb`: Destroys all enemies on the screen.

## Installation

### Prerequisites

To run this project, you will need:

- Elixir
- Phoenix Framework
- Postgres

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

3. Create the database:
   ```bash
   mix ecto.create
   mix ecto.migrate
   ```

4. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

5. Open your web browser and navigate to `http://localhost:4000` to play the game.


## Credits

- Game developed using Elixir and the Phoenix Framework.
- Inspired by the classic "Flappy Bird" game.
- Framework SVGs: Angular, React, Node, and Ruby on Rails.
- Other SVGs: Elixir, Oban

Enjoy the game and good luck flying your phoenix! 🐦‍🔥

If you encounter any issues or have suggestions, feel free to contribute or open an issue in the repository.

---

Disclaimer:
This project is a personal side project developed to explore game development concepts using Elixir and the Phoenix Framework. The logos and assets used, including those of open-source frameworks such as Angular, React, Node, Ruby on Rails, Elixir, and Oban, are included in good faith under fair use principles for educational and illustrative purposes only. All referenced logos and trademarks are the property of their respective owners. This project is not affiliated with, endorsed by, or sponsored by any of the frameworks, their maintainers, or associated organizations.
