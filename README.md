# Evo / MonkeyWorld

MonkeyWorld is a Delphi FireMonkey simulation project for exploring natural selection through simple agents called monkeys. The long-term idea is to model psychological or strategy evolution rather than a biological ecosystem with food, terrain, or explicit resources.

The project is currently in an early UI and architecture stage. The design is described in `Natural_Selection_Simulation.docx`, and the main application form is implemented in `UMonkeysForm.pas` / `UMonkeysForm.fmx`.

## Goal

The simulation creates a 2D grid world with a finite number of cells. Monkeys live on the board, perceive nearby cells, remember what they have seen, decide how to move, and survive or reproduce based on inherited traits and neural-network-driven behavior.

The main goal is to let selection emerge from:

- lifespan
- strength
- reproduction
- combat
- inherited traits
- inherited neural network weights
- finite board space
- local perception and memory

There is intentionally no food, energy, terrain, or external resource model. Survival pressure comes from lifespan, mating cost, combat, available space, and the decisions made by each monkey.

## Core Design

The world is an `M x N` grid. Each cell is empty or occupied by a monkey, with special temporary cases for mating or combat.

Each monkey has:

- sex
- age and lifespan
- strength
- generation count
- parent and grandparent IDs
- vision slots
- spatial memory
- neural network weights
- pregnancy and offspring state for females

On each turn, a monkey senses the board, updates memory, uses its neural network to choose movement and mating behavior, and requests a move from the world. The world resolves movement, collisions, mating, combat, birth, and death.

## User Interface

The FireMonkey UI currently has three tabs:

- **World**: shows the board and basic simulation controls.
- **Configuration & Statistics**: contains configurable simulation parameters and will later show runtime statistics.
- **NN view**: reserved for neural network inspection or visualization.

The world board is drawn on a `TPaintBox` as a light gray and white chess-style grid. The board size is read from the configuration controls.

## Configurable Parameters

The configuration tab is intended to control:

- world size X and Y
- base lifespan
- vision slots
- initial strength
- mating cost
- combat gain
- combat probability sigma
- mutation sigma
- initial trait variation sigma
- initial population count

## Development Status

Implemented so far:

- Delphi / FireMonkey project structure
- tabbed main form
- configuration controls
- world board paint box
- restart-board logic that reads board size and draws the grid
- Git repository setup

Planned next steps:

- board data model
- monkey class/model
- initial population placement
- turn ordering
- movement and collision resolution
- mating, pregnancy, birth, and death rules
- memory and vision systems
- neural network decision model
- statistics display
- save/export of successful neural network weights

## Building

Open `MonkeyWorld.dproj` in RAD Studio / Delphi and build the FireMonkey application.

Generated build outputs, IDE history, recovery files, and local machine state are ignored by Git.
