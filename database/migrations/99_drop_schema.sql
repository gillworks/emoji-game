-- First disable row level security on all tables
ALTER TABLE players DISABLE ROW LEVEL SECURITY;
ALTER TABLE emoji_choices DISABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users DISABLE ROW LEVEL SECURITY;
ALTER TABLE game_configs DISABLE ROW LEVEL SECURITY;
ALTER TABLE servers DISABLE ROW LEVEL SECURITY;
ALTER TABLE server_players DISABLE ROW LEVEL SECURITY;
ALTER TABLE map_data DISABLE ROW LEVEL SECURITY;
ALTER TABLE player_positions DISABLE ROW LEVEL SECURITY;
ALTER TABLE items DISABLE ROW LEVEL SECURITY;
ALTER TABLE player_inventory DISABLE ROW LEVEL SECURITY;
ALTER TABLE item_terrain_actions DISABLE ROW LEVEL SECURITY;
ALTER TABLE structures DISABLE ROW LEVEL SECURITY;
ALTER TABLE crafting_recipes DISABLE ROW LEVEL SECURITY;
ALTER TABLE crafting_ingredients DISABLE ROW LEVEL SECURITY;
ALTER TABLE resource_spawns DISABLE ROW LEVEL SECURITY;
ALTER TABLE storage_inventories DISABLE ROW LEVEL SECURITY;

-- Drop all policies
DROP POLICY IF EXISTS "Users can insert their own player record" ON players;
DROP POLICY IF EXISTS "Users can update their own player record" ON players;
DROP POLICY IF EXISTS "Users can view all player records" ON players;
DROP POLICY IF EXISTS "Authenticated users can view emoji choices" ON emoji_choices;
DROP POLICY IF EXISTS "Admin users are viewable by authenticated users" ON admin_users;
DROP POLICY IF EXISTS "Configs are readable by all authenticated users" ON game_configs;
DROP POLICY IF EXISTS "Only admins can modify configs" ON game_configs;
DROP POLICY IF EXISTS "Allow anonymous users to create servers" ON servers;
DROP POLICY IF EXISTS "Allow anonymous users to read servers" ON servers;
DROP POLICY IF EXISTS "Servers are viewable by all authenticated users" ON servers;
DROP POLICY IF EXISTS "Authenticated users can create servers" ON servers;
DROP POLICY IF EXISTS "Server players is viewable by all authenticated users" ON server_players;
DROP POLICY IF EXISTS "Players can join servers" ON server_players;
DROP POLICY IF EXISTS "Players can leave servers" ON server_players;
DROP POLICY IF EXISTS "Allow anonymous users to insert map data" ON map_data;
DROP POLICY IF EXISTS "Allow anonymous users to read map data" ON map_data;
DROP POLICY IF EXISTS "Map data can be inserted by authenticated users" ON map_data;
DROP POLICY IF EXISTS "Map data can be updated by authenticated users" ON map_data;
DROP POLICY IF EXISTS "Map data is viewable by all authenticated users" ON map_data;
DROP POLICY IF EXISTS "Players can insert their own position" ON player_positions;
DROP POLICY IF EXISTS "Players can update their own position" ON player_positions;
DROP POLICY IF EXISTS "Players can delete their own position" ON player_positions;
DROP POLICY IF EXISTS "All players can view positions" ON player_positions;
DROP POLICY IF EXISTS "Items are viewable by everyone" ON items;
DROP POLICY IF EXISTS "Players can view their own inventory" ON player_inventory;
DROP POLICY IF EXISTS "Players can insert into their own inventory" ON player_inventory;
DROP POLICY IF EXISTS "Players can update their own inventory" ON player_inventory;
DROP POLICY IF EXISTS "Players can delete from their own inventory" ON player_inventory;
DROP POLICY IF EXISTS "Item actions are viewable by everyone" ON item_terrain_actions;
DROP POLICY IF EXISTS "Structures are viewable by everyone" ON structures;
DROP POLICY IF EXISTS "Recipes are viewable by everyone" ON crafting_recipes;
DROP POLICY IF EXISTS "Ingredients are viewable by everyone" ON crafting_ingredients;
DROP POLICY IF EXISTS "Resources are viewable by all authenticated users" ON resource_spawns;
DROP POLICY IF EXISTS "Storage contents are viewable by all authenticated users" ON storage_inventories;
DROP POLICY IF EXISTS "Storage contents can only be modified by structure owner" ON storage_inventories;
DROP POLICY IF EXISTS "Allow portal configuration" ON map_data;

-- Remove tables from realtime publication
ALTER PUBLICATION supabase_realtime DROP TABLE map_data;
ALTER PUBLICATION supabase_realtime DROP TABLE player_positions;
ALTER PUBLICATION supabase_realtime DROP TABLE resource_spawns;

-- Drop all functions
DROP FUNCTION IF EXISTS increment_server_players(UUID);
DROP FUNCTION IF EXISTS decrement_server_players(UUID);
DROP FUNCTION IF EXISTS cleanup_inactive_servers();
DROP FUNCTION IF EXISTS cleanup_player(UUID, UUID);
DROP FUNCTION IF EXISTS handle_cleanup_request();
DROP FUNCTION IF EXISTS try_spawn_resource(UUID, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS handle_item_action(UUID, INTEGER, INTEGER, INTEGER, UUID);
DROP FUNCTION IF EXISTS handle_crafting(UUID, UUID, INTEGER, INTEGER, UUID);
DROP FUNCTION IF EXISTS handle_storage_action(UUID, UUID, INTEGER, INTEGER, storage_action, INTEGER, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS handle_server_transport(UUID, UUID, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS configure_portal(UUID, INTEGER, INTEGER, UUID, INTEGER, INTEGER);

-- Drop all tables in reverse order of creation (to handle dependencies)
DROP TABLE IF EXISTS storage_inventories;
DROP TABLE IF EXISTS resource_spawns;
DROP TABLE IF EXISTS crafting_ingredients;
DROP TABLE IF EXISTS crafting_recipes;
DROP TABLE IF EXISTS structures;
DROP TABLE IF EXISTS item_terrain_actions;
DROP TABLE IF EXISTS player_inventory;
DROP TABLE IF EXISTS items;
DROP TABLE IF EXISTS player_positions;
DROP TABLE IF EXISTS map_data;
DROP TABLE IF EXISTS terrain_types;
DROP TABLE IF EXISTS server_players;
DROP TABLE IF EXISTS servers;
DROP TABLE IF EXISTS game_configs;
DROP TABLE IF EXISTS admin_users;
DROP TABLE IF EXISTS emoji_choices;
DROP TABLE IF EXISTS players;

-- Drop custom types
DROP TYPE IF EXISTS item_action_type;
DROP TYPE IF EXISTS move_result;
DROP TYPE IF EXISTS storage_action;

-- Drop extensions (optional - uncomment if you want to remove extensions)
-- DROP EXTENSION IF EXISTS "uuid-ossp"; 