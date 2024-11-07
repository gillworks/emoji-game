# Emoji Adventure Documentation

A real-time multiplayer browser game where players explore a procedurally generated emoji world, battle creatures, and interact with other players.

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
- Tool system:
  - 🪓 Axe (Slot 1): Used to chop down trees
  - 🏹 Bow (Slot 2)
  - 🪄 Magic Wand (Slot 3)
  - 🍖 Food (Slot 4)
  - 🧪 Potion (Slot 5)
- Slot selection via number keys or clicking
- Visual selection feedback

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

## Technical Requirements

- Modern web browser with JavaScript enabled
- Internet connection for multiplayer features
- Email address for account creation
