-- Update collect_resource function to use items.max_stack
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
  v_existing_slot integer;
  v_max_stack integer;
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

  -- Get item details including max_stack
  SELECT emoji, name, COALESCE(max_stack, 64) INTO v_item_emoji, v_item_name, v_max_stack
  FROM items WHERE id = v_item_id;

  -- First try to find an existing stack that isn't full
  SELECT slot INTO v_existing_slot
  FROM player_inventory pi
  WHERE pi.player_id = p_player_id 
    AND pi.item_id = v_item_id
    AND pi.quantity < v_max_stack
  LIMIT 1;

  -- If we found a stack to add to
  IF v_existing_slot IS NOT NULL THEN
    UPDATE player_inventory
    SET quantity = quantity + 1
    WHERE player_id = p_player_id 
      AND slot = v_existing_slot;
    
    v_next_slot := v_existing_slot;
  ELSE
    -- Find next empty slot if no existing stack
    SELECT MIN(s.slot)
    INTO v_next_slot
    FROM generate_series(1, 10) s(slot)
    LEFT JOIN player_inventory pi ON 
      pi.player_id = p_player_id AND pi.slot = s.slot
    WHERE pi.player_id IS NULL;

    -- If no empty slot, inventory is full
    IF v_next_slot IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Inventory is full'
      );
    END IF;

    -- Add item to new slot
    INSERT INTO player_inventory (player_id, slot, item_id, quantity)
    VALUES (p_player_id, v_next_slot, v_item_id, 1);
  END IF;

  -- Try spawn new resource
  PERFORM try_spawn_resource(p_server_id, p_x, p_y);

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Picked up ' || v_item_emoji || ' ' || v_item_name
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 