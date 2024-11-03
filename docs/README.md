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

### World

- Procedurally generated maps
- Four terrain types:
  - 🌳 Forest (Wolf encounters)
  - 🏔️ Mountains (Leopard encounters)
  - 🌱 Plains (Lion encounters)
  - 🌊 Ocean (Shark encounters)
- Dynamic map rendering with pan controls
- Viewport management for large maps

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

## Technical Requirements

- Modern web browser with JavaScript enabled
- Internet connection for multiplayer features
- Email address for account creation
