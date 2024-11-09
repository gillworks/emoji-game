-- Create enum for move result types
CREATE TYPE move_result AS ENUM ('MOVE', 'SWAP', 'STACK');

-- Create function to handle inventory item movement
CREATE OR REPLACE FUNCTION move_inventory_item(
  p_player_id UUID,
  p_from_slot INTEGER,
  p_to_slot INTEGER
) RETURNS jsonb AS $$
DECLARE
  v_from_item RECORD;
  v_to_item RECORD;
  v_item_details RECORD;
  v_max_stack INTEGER;
  v_move_type move_result;
  v_message TEXT;
BEGIN
  -- Get items in both slots
  SELECT item_id, quantity INTO v_from_item 
  FROM player_inventory 
  WHERE player_id = p_player_id AND slot = p_from_slot;

  SELECT item_id, quantity INTO v_to_item
  FROM player_inventory 
  WHERE player_id = p_player_id AND slot = p_to_slot;

  -- Validate source slot has an item
  IF v_from_item IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'No item to move'
    );
  END IF;

  -- Get item details including max stack
  SELECT i.stackable, COALESCE(i.max_stack, 64) as max_stack, i.name
  INTO v_item_details
  FROM items i
  WHERE i.id = v_from_item.item_id;

  -- Determine move type
  IF v_to_item IS NULL THEN
    v_move_type := 'MOVE';
  ELSIF v_to_item.item_id = v_from_item.item_id AND v_item_details.stackable THEN
    v_move_type := 'STACK';
  ELSE
    v_move_type := 'SWAP';
  END IF;

  -- Handle each move type
  CASE v_move_type
    WHEN 'MOVE' THEN
      -- Simple move to empty slot
      UPDATE player_inventory
      SET slot = p_to_slot
      WHERE player_id = p_player_id AND slot = p_from_slot;
      
      v_message := 'Item moved';

    WHEN 'STACK' THEN
      -- Calculate how much can be stacked
      IF v_to_item.quantity >= v_item_details.max_stack THEN
        RETURN jsonb_build_object(
          'success', false,
          'message', 'Target stack is full'
        );
      END IF;

      DECLARE
        v_space_in_stack INTEGER := v_item_details.max_stack - v_to_item.quantity;
        v_amount_to_move INTEGER := LEAST(v_space_in_stack, v_from_item.quantity);
      BEGIN
        -- Add to target stack
        UPDATE player_inventory
        SET quantity = quantity + v_amount_to_move
        WHERE player_id = p_player_id AND slot = p_to_slot;

        -- Remove from source stack
        IF v_amount_to_move = v_from_item.quantity THEN
          DELETE FROM player_inventory
          WHERE player_id = p_player_id AND slot = p_from_slot;
        ELSE
          UPDATE player_inventory
          SET quantity = quantity - v_amount_to_move
          WHERE player_id = p_player_id AND slot = p_from_slot;
        END IF;

        v_message := format('Stacked %s %s', v_amount_to_move, v_item_details.name);
      END;

    WHEN 'SWAP' THEN
      -- Store the current items
      DECLARE
        v_from_item_id TEXT := v_from_item.item_id;
        v_from_quantity INTEGER := v_from_item.quantity;
        v_to_item_id TEXT := v_to_item.item_id;
        v_to_quantity INTEGER := v_to_item.quantity;
      BEGIN
        -- Delete both items
        DELETE FROM player_inventory 
        WHERE player_id = p_player_id 
        AND slot IN (p_from_slot, p_to_slot);

        -- Reinsert them in swapped positions
        INSERT INTO player_inventory (player_id, slot, item_id, quantity)
        VALUES 
          (p_player_id, p_to_slot, v_from_item_id, v_from_quantity),
          (p_player_id, p_from_slot, v_to_item_id, v_to_quantity);
      END;
      
      v_message := 'Items swapped';
  END CASE;

  RETURN jsonb_build_object(
    'success', true,
    'message', v_message
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to handle resource collection with stacking
CREATE OR REPLACE FUNCTION collect_resource(
  p_player_id UUID,
  p_server_id UUID,
  p_x INTEGER,
  p_y INTEGER
) RETURNS jsonb AS $$
DECLARE
  v_resource RECORD;
  v_item RECORD;
  v_quantity INTEGER;
  v_slot INTEGER;
  v_existing_slot INTEGER;
  v_existing_quantity INTEGER;
  v_debug jsonb;
BEGIN
  -- Get the resource at this location
  SELECT rs.*, i.name, i.emoji, i.stackable, COALESCE(i.max_stack, 64) as max_stack
  INTO v_resource
  FROM resource_spawns rs
  JOIN items i ON i.id = rs.item_id
  WHERE rs.server_id = p_server_id 
    AND rs.x = p_x 
    AND rs.y = p_y;

  IF v_resource IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'No resource found here'
    );
  END IF;

  -- Generate random quantity (1-3)
  v_quantity := floor(random() * 3 + 1)::integer;

  -- Get current inventory state for debugging
  SELECT jsonb_agg(jsonb_build_object(
    'slot', slot,
    'item_id', item_id,
    'quantity', quantity
  ))
  INTO v_debug
  FROM player_inventory
  WHERE player_id = p_player_id;

  -- Only look for existing stacks if item is stackable
  IF v_resource.stackable THEN
    SELECT slot, quantity 
    INTO v_existing_slot, v_existing_quantity
    FROM player_inventory
    WHERE player_id = p_player_id 
      AND item_id = v_resource.item_id
      AND quantity < v_resource.max_stack
    ORDER BY slot
    LIMIT 1;
  END IF;

  -- If we found an existing stack with space
  IF v_resource.stackable AND v_existing_slot IS NOT NULL THEN
    -- Calculate how much we can add to the stack
    v_quantity := LEAST(
      v_quantity, 
      v_resource.max_stack - v_existing_quantity
    );
    
    -- Update existing stack
    UPDATE player_inventory
    SET quantity = quantity + v_quantity
    WHERE player_id = p_player_id AND slot = v_existing_slot;
  ELSE
    -- Find first empty slot
    SELECT MIN(s.slot)
    INTO v_slot
    FROM generate_series(1, 10) s(slot)
    WHERE NOT EXISTS (
      SELECT 1
      FROM player_inventory
      WHERE player_id = p_player_id AND slot = s.slot
    );

    IF v_slot IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Inventory is full'
      );
    END IF;

    -- Insert new stack
    INSERT INTO player_inventory (player_id, slot, item_id, quantity)
    VALUES (p_player_id, v_slot, v_resource.item_id, v_quantity);
  END IF;

  -- Delete the resource
  DELETE FROM resource_spawns
  WHERE server_id = p_server_id AND x = p_x AND y = p_y;

  -- Return with debug info
  RETURN jsonb_build_object(
    'success', true,
    'message', format('Collected %s %s', v_quantity, v_resource.name),
    'debug', jsonb_build_object(
      'resource', jsonb_build_object(
        'id', v_resource.item_id,
        'stackable', v_resource.stackable,
        'max_stack', v_resource.max_stack
      ),
      'existing_slot', v_existing_slot,
      'existing_quantity', v_existing_quantity,
      'new_quantity', v_quantity,
      'inventory_before', v_debug
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION move_inventory_item TO authenticated;
GRANT EXECUTE ON FUNCTION collect_resource TO authenticated; 