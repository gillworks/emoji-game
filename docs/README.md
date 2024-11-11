# Emoji Adventure Documentation

A real-time multiplayer browser game where players explore a procedurally generated emoji world, battle creatures, gather resources, craft items, and build structures.

## Installation

1. Clone the repository:

```bash
git clone [your-repo-url]
cd emoji-game
```

2. Install dependencies:

```bash
npm install
```

3. Create a `.env.local` file in the root directory:

```bash
# Supabase Configuration
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
```

4. Generate the config file:

```bash
npm run generate-config
```

5. Start a local server:

```bash
python -m http.server 8000
# Or use your preferred local server
```

6. Open your browser and navigate to:

```
http://localhost:8000
```

### Prerequisites

- Node.js (v14 or higher)
- Python 3.x (for terrain generation and local server)
- A modern web browser
- A Supabase account and project

### Development Notes

- The `config.js` file is generated from your `.env.local` and should not be committed to git
- After making changes to `.env.local`, run `npm run generate-config` to update your configuration
- The terrain generator requires Python with additional packages:
  ```bash
  pip install python-dotenv supabase noise
  ```

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

### House Interiors

- Houses (🏠) can be entered using 'E'
- Each house has its own interior server with:
  - Floor tiles (🟫) for walking space
  - Door (🚪) for exiting back to main world
  - Storage chests (🗄️) along walls for public storage
- Press 'E' at the door to return to the main world
- All storage chests in houses are public (accessible by anyone)
- Players appear in front of the house when exiting

### Inventory System

- 10-slot hotbar (keys 1-0)
- Inventory management features:
  - Click and drag items between slots
  - Auto-stacking of identical items
  - Visual feedback for selected items
  - Stack size display
  - Maximum stack sizes per item type
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
- Terrain-specific building requirements
- Resource costs for each structure
- Real-time structure placement
- Structure ownership tracking
- Safe zones (no encounters in structures)

### Resource System

- Random resource spawning based on terrain type:
  - 🌱 Plains: Stones (15% chance)
  - 🌳 Forest: Mushrooms (5% chance), Wood (15% chance)
  - 🏔️ Mountains: Stones (20% chance), Crystals (5% chance)
- Press 'E' to collect resources
- Automatic resource respawning:
  - Resources respawn periodically (every 5 minutes)
  - Configurable spawn rates and intervals
  - Resources can be collected by any player
  - Real-time resource updates across all players
- Inventory stacking system:
  - Resources automatically stack in inventory
  - Stack sizes configurable per item type
  - Visual feedback when collecting items

### Storage System

- Two types of storage chests:
  - 🗄️ Public chests: Found in building interiors, accessible by all players
  - 📦 Private chests: Player-built, only accessible by owner
- 20 storage slots per chest
- Intuitive interface with keyboard controls:
  - Arrow keys to move cursor
  - Tab to switch between storage and inventory
  - X to transfer items
  - ESC to close storage menu
- Mouse support:
  - Click slots to move cursor
  - Click transfer button or press X to move items
- Automatic slot finding:
  - Automatically finds first empty slot when transferring
  - Prevents item loss by checking available space
- Visual feedback:
  - Gold highlight shows cursor position
  - Disabled transfer button when no item under cursor
  - Stack size indicators
  - Hotkey numbers visible on inventory slots
- Security features:
  - Only chest owner can access contents
  - Items persist across sessions
  - Protected by row-level security

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

### Inventory Management

- Click an item to select it for moving
- Click another slot to:
  - Move the item there if empty
  - Stack with matching items (if stackable)
  - Swap with different items
- Click the same slot again to cancel move
- Numbers 1-0: Quick select inventory slots
- Visual feedback shows selected items with green highlight
- Stack counts shown in bottom-right of slots

### Storage Controls

- E: Open storage chest (when standing on one)
- Arrow keys: Move cursor between slots
- Tab: Switch between storage and inventory sections
- X: Transfer item under cursor
- ESC: Close storage menu
- Mouse: Click slots to move cursor

### Building Storage

- Open build menu (B)
- Select Storage Chest
- Requires:
  - 4x Wood
  - 2x Stone
- Can only be built on plains
- Each player can access only their own chests

## Technical Requirements

- Modern web browser with JavaScript enabled
- Internet connection for multiplayer features
- Email address for account creation
