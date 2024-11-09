# Emoji Adventure Documentation

A real-time multiplayer browser game where players explore a procedurally generated emoji world, battle creatures, gather resources, craft items, and build structures.

## Game Features

### Authentication

- Email-based authentication system
- Email confirmation required for new accounts
- Secure password requirements

### Multiplayer

- Real-time player position updates
- Multiple game servers support
- Server-based player management
- Automatic server cleanup for inactive players
- Customizable player characters (🐻🐸🐵🐨🐷)

### World

- Procedurally generated maps
- Four terrain types:
  - 🌳 Forest (Wolf encounters, can be chopped down)
  - 🏔️ Mountains (Leopard encounters)
  - 🌱 Plains (Lion encounters)
  - 🌊 Ocean (Shark encounters)
- Dynamic map rendering with pan controls
- Viewport management for large maps
- Terrain modification system
- Map reset functionality

### Inventory System

- 10-slot hotbar (keys 1-0)
- Tool system with multiple tools:
  - 🪓 Axe: Used to chop trees for wood (3 hits to fell a tree)
  - ⛏️ Pickaxe: Used to mine stone from mountains
  - 🎣 Fishing Rod: Used to catch fish in oceans
- Resources:
  - 🪵 Wood: Obtained from chopping trees
  - 🪨 Stone: Obtained from mining mountains
  - 🐟 Fish: Caught in oceans
- Stack system with configurable limits
- Persistent inventory across sessions
- Crafting system for creating tools and items
- Visual feedback for gathering and crafting

### Resource Gathering

- Progressive resource gathering:
  - Trees require multiple hits to fell
  - Different success rates for different tools
  - Random resource quantities
- Terrain transformation:
  - Trees transform to empty forest after being felled
  - Resource nodes can regenerate when map resets
- Tool-specific actions:
  - Axes work on forests
  - Pickaxes work on mountains
  - Fishing rods work in oceans

### Crafting System

- Multiple ingredients per recipe
- Quantity-based crafting
- Example recipes:
  - Axe: 2x Wood + 1x Stone
  - Fishing Rod: 3x Wood
- Clear feedback on missing materials
- Automatic inventory management
- Stack-aware crafting system

### Battle System

- Random encounters based on terrain type
- Three combat options:
  - Quick Attack (🌪️)
  - Heavy Attack (🔨)
  - Block (🛡️)
- Rock-paper-scissors style combat mechanics
- Run option with chance of escape
- Health and score tracking
- Victory/defeat animations

### Building System

- Press 'B' to open building menu
- Multiple structure types:
  - 🏠 House: A cozy shelter
  - 🌾 Farm: Grows food
  - 🏭 Workshop: Crafting station
- Terrain-specific building requirements
- Resource costs for each structure
- Real-time structure placement
- Structure ownership tracking
- Safe zones (no encounters in structures)

### Technical Features

- Real-time database with Supabase
- Row Level Security (RLS) for data protection
- Optimized database queries with indexes
- Automatic server cleanup processes
- Responsive design
- Keyboard controls (WASD/Arrow keys, F, R, 1-3)

## Database Structure

The game uses several interconnected tables:

- players: User information
- player_positions: Real-time position tracking
- terrain_types: World environment definitions
- game_configs: Server-wide settings
- servers: Game instance management
- map_data: Terrain storage
- server_players: Player-server relationships
- items: Defines all available items and their properties
- item_terrain_actions: Defines how items interact with terrain
- crafting_recipes: Defines available crafting recipes
- crafting_ingredients: Defines recipe requirements

For detailed database information, see [Database Schema](database/schema.md)

## Controls

### Movement

- W/↑: Move up
- S/↓: Move down
- A/←: Move left
- D/→: Move right

### Battle

- F: Fight
- R: Run
- 1: Quick Attack
- 2: Heavy Attack
- 3: Block

### Crafting

- C: Open/close crafting menu
- ↑/↓: Navigate recipes
- C: Craft selected recipe
- ESC: Close crafting menu

### Map Navigation

- Click and drag to pan the map
- Map automatically centers on player

### Tools

- 1/Click: Select and use axe (chops trees when on forest tiles)
- 2-0: Select other inventory slots

### Character Customization

- Click your character emoji in the status bar to open the emoji selector
- Choose from available characters:
  - 🐻 Bear (default)
  - 🐸 Frog
  - 🐵 Monkey
  - 🐨 Koala
  - 🐷 Pig

### Building

- B: Open/close building menu
- ↑/↓: Navigate structures
- B: Build selected structure
- ESC: Close building menu

## Technical Requirements

- Modern web browser with JavaScript enabled
- Internet connection for multiplayer features
- Email address for account creation
