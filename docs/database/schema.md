# Database Schema

This document outlines the database schema for the Emoji Adventure game.

## Tables

### players

Stores player information
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key, matches Supabase auth.users id |
| username | text | Player's username (derived from email) |
| emoji | text | Player's chosen character emoji (default: 🐻) |
| created_at | timestamp | When the player record was created |

### emoji_choices

Stores available emoji choices for players
| Column | Type | Description |
|--------|------|-------------|
| id | serial | Primary key |
| emoji | text | The emoji character |
| name | text | Display name for the emoji |
| enabled | boolean | Whether this emoji is available (default: true) |
| created_at | timestamp | When the emoji choice was added |

### player_positions

Stores current position of players on the map
| Column | Type | Description |
|--------|------|-------------|
| player_id | uuid | Part of composite primary key, foreign key to players.id |
| server_id | uuid | Part of composite primary key, foreign key to servers.id |
| x | integer | X coordinate on game map |
| y | integer | Y coordinate on game map |
| updated_at | timestamp | Last update timestamp |

### terrain_types

Defines the different types of terrain and their associated encounters
| Column | Type | Description |
|--------|------|-------------|
| id | text | Primary key |
| emoji | text | Emoji representation of terrain |
| encounter | text | Emoji representation of encounter |
| color | text | Background color in rgba format |

Example terrain types:

- FOREST (🌳) - Forest with trees, green background
- EMPTY_FOREST (🌱) - Cleared forest area, green background
- MOUNTAIN (🏔️) - Mountain terrain, gray background
- PLAIN (🌱) - Plains/grassland, lime background
- OCEAN (🌊) - Ocean/water, blue background

### game_configs

Stores server-wide game configuration values
| Column | Type | Description |
|--------|------|-------------|
| key | text | Primary key, configuration key |
| value | jsonb | Configuration value |
| updated_at | timestamp | Last update timestamp |

### admin_users

Stores users with administrative privileges
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key, foreign key to auth.users(id) |
| created_at | timestamp | When the admin was added |

### servers

Manages game server instances
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| name | text | Server name |
| status | text | Server status (active/inactive) |
| created_at | timestamp | When server was created |
| last_active | timestamp | Last activity timestamp |
| max_players | integer | Maximum allowed players |
| map_width | integer | Width of the server's map (default: 20) |
| map_height | integer | Height of the server's map (default: 20) |

### map_data

Stores the terrain type for each coordinate on each server's map
| Column | Type | Description |
|--------|------|-------------|
| server_id | uuid | Foreign key to servers.id |
| x | integer | X coordinate |
| y | integer | Y coordinate |
| terrain_type | text | Current type of terrain at this location |
| original_terrain_type | text | Original type of terrain (for map resets) |

### server_players

Tracks which players are on which servers
| Column | Type | Description |
|--------|------|-------------|
| server_id | uuid | Foreign key to servers.id |
| player_id | uuid | Foreign key to players.id |
| joined_at | timestamp | When player joined server |

### player_inventory

Stores player inventory items and quantities
| Column | Type | Description |
|--------|------|-------------|
| player_id | uuid | Part of composite primary key, foreign key to players.id |
| slot | integer | Part of composite primary key, slot number (1-10) |
| item_id | text | Foreign key to items.id |
| quantity | integer | Stack size for the item |

### items

Stores all available items in the game
| Column | Type | Description |
|--------|------|-------------|
| id | text | Primary key (e.g., 'AXE', 'WOOD') |
| emoji | text | Visual representation of item |
| name | text | Display name for the item |
| stackable | boolean | Whether items can stack (default: true) |
| max_stack | integer | Maximum stack size (default: 64) |
| created_at | timestamp | When the item was added |

### item_terrain_actions

Defines how items interact with terrain
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| item_id | text | Foreign key to items.id |
| terrain_type | text | Foreign key to terrain_types.id |
| action_type | item_action_type | Either 'GATHER' or 'TRANSFORM' |
| result_item_id | text | Foreign key to items.id for result |
| min_quantity | integer | Minimum items received (default: 1) |
| max_quantity | integer | Maximum items received (default: 1) |
| success_rate | decimal | Chance of success (0.0-1.0) |
| hits_to_transform | integer | Hits needed before transformation |
| current_hits | jsonb | Tracks hits per location |
| cooldown_seconds | integer | Time between actions (default: 0) |

### crafting_recipes

Defines recipes for creating items
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| result_item_id | text | Foreign key to items.id |
| quantity_produced | integer | Amount crafted (default: 1) |
| created_at | timestamp | When recipe was added |

### crafting_ingredients

Stores ingredients needed for recipes
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| recipe_id | uuid | Foreign key to crafting_recipes.id |
| item_id | text | Foreign key to items.id |
| quantity_required | integer | Amount needed (default: 1) |
| created_at | timestamp | When ingredient was added |

## Row Level Security (RLS)

All tables have RLS enabled with appropriate policies:

### players

- Users can insert/update their own records
- All authenticated users can view player records

### player_positions

- Players can insert their own position
- Players can update their own position
- Players can delete their own position
- All authenticated users can view positions

### game_configs

- All authenticated users can view configs
- Only admins can modify configs

### servers

- All authenticated users can view servers
- Authenticated users can create servers

### map_data

- All authenticated users can view map data
- Authenticated users can insert map data

### server_players

- All authenticated users can view server players
- Players can join/leave servers they belong to

### player_inventory

- Players can view only their own inventory items
- Players can insert/update/delete only their own inventory items
- No other players can view or modify another player's inventory

### items

- All authenticated users can view items
- Only admins can modify items

### item_terrain_actions

- All authenticated users can view actions
- Only admins can modify actions

### crafting_recipes and crafting_ingredients

- All authenticated users can view recipes and ingredients
- Only admins can modify recipes

## Stored Procedures

### cleanup_player(player_id UUID, server_id UUID)

Removes a player's data from a server:

- Deletes their position from player_positions
- Removes them from server_players

### handle_cleanup_request()

API endpoint for cleanup_player that uses the authenticated user's ID

### reset_server_map(server_id UUID)

Resets all tiles on a server back to their original terrain:

- Updates terrain_type to match original_terrain_type for all tiles
- Only accessible to authenticated users

### handle_item_action(player_id UUID, item_slot INTEGER, x INTEGER, y INTEGER, server_id UUID)

Handles item usage on terrain:

- Checks if action is valid for item/terrain combination
- Applies success rate and random quantities
- Updates inventory with gathered resources
- Tracks hits for transformation
- Returns success/failure message

### handle_crafting(player_id UUID, recipe_id UUID)

Handles item crafting:

- Verifies player has required ingredients
- Removes ingredients from inventory
- Adds crafted item to inventory
- Returns success/failure message

## Indexes

The following indexes improve query performance:

- idx_player_positions_player_server on player_positions(player_id, server_id)
- idx_player_positions_server on player_positions(server_id)
- idx_server_players_server on server_players(server_id)
- idx_server_players_combined on server_players(server_id, player_id)

## Realtime Subscriptions

The following tables have realtime enabled:

- player_positions (for live player movement, filtered by server_id)

## Initial Data

The database is seeded with:

- Basic terrain types (FOREST, MOUNTAIN, PLAIN, OCEAN, EMPTY_FOREST)
- Default encounter rates in game_configs (including EMPTY_FOREST)
