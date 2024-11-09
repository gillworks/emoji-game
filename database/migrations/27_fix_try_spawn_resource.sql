-- Fix try_spawn_resource function to properly handle jsonb
CREATE OR REPLACE FUNCTION try_spawn_resource(
  p_server_id uuid,
  p_x integer,
  p_y integer
) RETURNS void AS $$
DECLARE
  v_terrain_type text;
  v_spawn_items jsonb;
  v_item jsonb;
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
  FOR v_item IN SELECT jsonb_array_elements(v_spawn_items)
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