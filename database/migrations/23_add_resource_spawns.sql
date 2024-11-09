-- Add resource_spawns table
CREATE TABLE resource_spawns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id uuid REFERENCES servers(id),
  x integer,
  y integer,
  item_id text REFERENCES items(id),
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE (server_id, x, y)
);

-- Add RLS policies
ALTER TABLE resource_spawns ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Resources are viewable by all authenticated users"
  ON resource_spawns FOR SELECT
  USING (auth.role() = 'authenticated');

-- Add spawn_rates to terrain_types
ALTER TABLE terrain_types 
ADD COLUMN spawn_items jsonb DEFAULT '[]'::jsonb;

-- Update terrain types with spawn rates
UPDATE terrain_types 
SET spawn_items = '[
  {"item_id": "STONE", "chance": 0.15}
]'::jsonb
WHERE id = 'PLAIN';

UPDATE terrain_types 
SET spawn_items = '[
  {"item_id": "MUSHROOM", "chance": 0.05},
  {"item_id": "WOOD", "chance": 0.15}
]'::jsonb
WHERE id = 'FOREST';

UPDATE terrain_types 
SET spawn_items = '[
  {"item_id": "STONE", "chance": 0.2},
  {"item_id": "CRYSTAL", "chance": 0.05}
]'::jsonb
WHERE id = 'MOUNTAIN';

-- Add new items
INSERT INTO items (id, emoji, name) VALUES
  ('MUSHROOM', '🍄', 'Mushroom'),
  ('CRYSTAL', '💎', 'Crystal');

-- Function to spawn resources
CREATE OR REPLACE FUNCTION try_spawn_resource(
  p_server_id uuid,
  p_x integer,
  p_y integer
) RETURNS void AS $$
DECLARE
  v_terrain_type text;
  v_spawn_items jsonb;
  v_item record;
BEGIN
  -- Get terrain type at location
  SELECT terrain_type INTO v_terrain_type
  FROM map_data
  WHERE server_id = p_server_id AND x = p_x AND y = p_y;

  -- Get spawn items for this terrain
  SELECT spawn_items INTO v_spawn_items
  FROM terrain_types
  WHERE id = v_terrain_type;

  -- Check each possible spawn
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_spawn_items)
  LOOP
    IF random() < (v_item->>'chance')::float THEN
      -- Attempt to insert new resource
      INSERT INTO resource_spawns (server_id, x, y, item_id)
      VALUES (p_server_id, p_x, p_y, v_item->>'item_id')
      ON CONFLICT (server_id, x, y) DO NOTHING;
      RETURN;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to collect resource
CREATE OR REPLACE FUNCTION collect_resource(
  p_player_id uuid,
  p_server_id uuid,
  p_x integer,
  p_y integer
) RETURNS jsonb AS $$
DECLARE
  v_item_id text;
  v_item_emoji text;
  v_item_name text;
  v_next_slot integer;
BEGIN
  -- Get and delete the resource
  DELETE FROM resource_spawns 
  WHERE server_id = p_server_id AND x = p_x AND y = p_y
  RETURNING item_id INTO v_item_id;

  IF v_item_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'No resource found here'
    );
  END IF;

  -- Get item details
  SELECT emoji, name INTO v_item_emoji, v_item_name
  FROM items WHERE id = v_item_id;

  -- Find next available inventory slot
  SELECT MIN(s.slot)
  INTO v_next_slot
  FROM generate_series(1, 10) s(slot)
  LEFT JOIN player_inventory pi ON 
    pi.player_id = p_player_id AND pi.slot = s.slot
  WHERE pi.player_id IS NULL;

  -- If no empty slot, try to stack
  IF v_next_slot IS NULL THEN
    UPDATE player_inventory
    SET quantity = quantity + 1
    WHERE player_id = p_player_id 
    AND item_id = v_item_id
    AND quantity < max_stack
    RETURNING slot INTO v_next_slot;
  END IF;

  -- If still no slot, inventory is full
  IF v_next_slot IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Inventory is full'
    );
  END IF;

  -- Add item to inventory
  INSERT INTO player_inventory (player_id, slot, item_id, quantity)
  VALUES (p_player_id, v_next_slot, v_item_id, 1)
  ON CONFLICT (player_id, slot) 
  DO UPDATE SET quantity = player_inventory.quantity + 1;

  -- Try spawn new resource
  PERFORM try_spawn_resource(p_server_id, p_x, p_y);

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Picked up ' || v_item_emoji || ' ' || v_item_name
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 