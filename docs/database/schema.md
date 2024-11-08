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
| item_type | text | Type of item (AXE, WOOD, etc.) |
| quantity | integer | Stack size for the item (default: 1) |

Available item types:

- AXE (🪓) - Tool for chopping trees
- WOOD (🪵) - Resource from chopping trees

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

## Stored Procedures

### cleanup_player(player_id UUID, server_id UUID)

Removes a player's data from a server:

- Deletes their position from player_positions
- Removes them from server_players

### handle_cleanup_request()

API endpoint for cleanup_player that uses the authenticated user's ID

### reset_server_map(server_id_param UUID)

Resets all tiles on a server back to their original terrain:

- Updates terrain_type to match original_terrain_type for all tiles
- Only accessible to authenticated users

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
