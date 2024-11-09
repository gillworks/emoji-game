-- Create enum for action types
CREATE TYPE item_action_type AS ENUM ('GATHER', 'TRANSFORM');

-- Create items table
CREATE TABLE items (
    id text PRIMARY KEY,
    emoji text NOT NULL,
    name text NOT NULL,
    stackable boolean DEFAULT true,
    max_stack integer DEFAULT 64,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

-- Create item_terrain_actions table
CREATE TABLE item_terrain_actions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    item_id text REFERENCES items(id),
    terrain_type text REFERENCES terrain_types(id),
    action_type item_action_type NOT NULL,
    result_item_id text REFERENCES items(id),
    min_quantity integer DEFAULT 1,
    max_quantity integer DEFAULT 1,
    success_rate decimal DEFAULT 1.0,
    cooldown_seconds integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

-- Add RLS policies
ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_terrain_actions ENABLE ROW LEVEL SECURITY;

-- Everyone can view items
CREATE POLICY "Items are viewable by everyone" ON items
    FOR SELECT USING (true);

-- Everyone can view item actions
CREATE POLICY "Item actions are viewable by everyone" ON item_terrain_actions
    FOR SELECT USING (true);

-- Insert initial data
INSERT INTO items (id, emoji, name) VALUES
    ('AXE', '🪓', 'Axe'),
    ('WOOD', '🪵', 'Wood'),
    ('PICKAXE', '⛏️', 'Pickaxe'),
    ('STONE', '🪨', 'Stone'),
    ('FISHING_ROD', '🎣', 'Fishing Rod'),
    ('FISH', '🐟', 'Fish');

-- Insert item-terrain actions
INSERT INTO item_terrain_actions 
    (item_id, terrain_type, action_type, result_item_id, min_quantity, max_quantity, success_rate)
VALUES
    ('AXE', 'FOREST', 'GATHER', 'WOOD', 1, 3, 1.0),
    ('PICKAXE', 'MOUNTAIN', 'GATHER', 'STONE', 1, 2, 0.8),
    ('FISHING_ROD', 'OCEAN', 'GATHER', 'FISH', 0, 1, 0.6);

-- Add new column first
ALTER TABLE player_inventory 
    ADD COLUMN item_id text REFERENCES items(id);

-- Migrate the data
UPDATE player_inventory 
SET item_id = CASE 
    WHEN item_type = 'AXE' THEN 'AXE'
    WHEN item_type = 'WOOD' THEN 'WOOD'
    ELSE NULL 
END;

-- Drop old column after migration
ALTER TABLE player_inventory 
    DROP COLUMN item_type;