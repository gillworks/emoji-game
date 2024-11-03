# Database Schema

This document outlines the database schema for the Emoji Adventure game.

## Tables

### players

Stores player information
| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key, matches Supabase auth.users id |
| username | text | Player's username (derived from email) |
| created_at | timestamp | When the player record was created |

### player_positions

Stores current position of players on the map
| Column | Type | Description |
|--------|------|-------------|
| player_id | uuid | Foreign key to players.id |
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
| current_players | integer | Current player count |
| map_width | integer | Width of the server's map (default: 20) |
| map_height | integer | Height of the server's map (default: 20) |

### map_data

Stores the terrain type for each coordinate on each server's map
| Column | Type | Description |
|--------|------|-------------|
| server_id | uuid | Foreign key to servers.id |
| x | integer | X coordinate |
| y | integer | Y coordinate |
| terrain_type | text | Type of terrain at this location |

### server_players

Tracks which players are on which servers
| Column | Type | Description |
|--------|------|-------------|
| server_id | uuid | Foreign key to servers.id |
| player_id | uuid | Foreign key to players.id |
| joined_at | timestamp | When player joined server |

## Row Level Security (RLS)

All tables have RLS enabled with appropriate policies:

### players

- Users can insert/update their own records
- All authenticated users can view player records

### player_positions

- Players can update their own position
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

## Stored Procedures

### increment_server_players(server_id UUID)

Increments the player count for a server and updates last_active timestamp

### decrement_server_players(server_id UUID)

Decrements the player count for a server and updates last_active timestamp

### cleanup_inactive_servers()

Automated cleanup of inactive servers and their associated data

## Realtime Subscriptions

The following tables have realtime enabled:

- player_positions (for live player movement)

## Initial Data

The database is seeded with:

- Basic terrain types (FOREST, MOUNTAIN, PLAIN, OCEAN)
- Default encounter rates in game_configs
