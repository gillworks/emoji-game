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

### map_tiles

Stores the terrain type for each coordinate on the map
| Column | Type | Description |
|--------|------|-------------|
| x | integer | X coordinate (part of composite primary key) |
| y | integer | Y coordinate (part of composite primary key) |
| terrain_type_id | text | Foreign key to terrain_types.id |

## Row Level Security (RLS)

### player_positions

- ✅ RLS enabled
- Policies:
  - "Players can update their own position"
    - Applies to: ALL operations
    - Condition: auth.uid() = player_id
  - "Player positions are visible to all"
    - Applies to: SELECT
    - Condition: true (for authenticated users)

### players

- ✅ RLS enabled
- Policies:
  - "Users can insert their own player record"
    - Applies to: INSERT
    - Condition: auth.uid() = id
  - "Users can update their own player record"
    - Applies to: UPDATE
    - Condition: auth.uid() = id
  - "Users can view all player records"
    - Applies to: SELECT
    - Condition: true (for authenticated users)

## Realtime Subscriptions

The following tables have realtime enabled:

- `player_positions` (via supabase_realtime publication)

## Full SQL Setup
