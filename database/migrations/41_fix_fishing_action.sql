-- Update handle_item_action to only add items on successful fishing
CREATE OR REPLACE FUNCTION handle_item_action(
    p_player_id UUID,
    p_item_slot INTEGER,
    p_x INTEGER,
    p_y INTEGER,
    p_server_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_item_type TEXT;
    v_terrain_type TEXT;
    v_result_item_id TEXT;
    v_result_item_emoji TEXT;
    v_min_quantity INTEGER;
    v_max_quantity INTEGER;
    v_result_quantity INTEGER;
    v_current_quantity INTEGER;
    v_max_stack INTEGER;
    v_fishing_success BOOLEAN;
    v_slot INTEGER;
    v_empty_slot INTEGER;
    v_new_quantity INTEGER;
    v_is_tool BOOLEAN;
    v_debug JSONB;
BEGIN
    -- Get the item being used and check if it's a tool
    SELECT i.id, i.id IN ('FISHING_ROD', 'AXE', 'PICKAXE')  -- List of tools that shouldn't be consumed
    INTO v_item_type, v_is_tool
    FROM player_inventory pi
    JOIN items i ON i.id = pi.item_id
    WHERE pi.player_id = p_player_id AND pi.slot = p_item_slot;

    IF v_item_type IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'No item in that slot'
        );
    END IF;

    -- Get the terrain type at the location
    SELECT terrain_type INTO v_terrain_type
    FROM map_data
    WHERE server_id = p_server_id AND x = p_x AND y = p_y;

    -- Get the result item and quantity range for this action
    SELECT ita.result_item_id, 
           ita.min_quantity,
           ita.max_quantity,
           i.emoji
    INTO v_result_item_id, v_min_quantity, v_max_quantity, v_result_item_emoji
    FROM item_terrain_actions ita
    JOIN items i ON i.id = ita.result_item_id
    WHERE ita.item_id = v_item_type AND ita.terrain_type = v_terrain_type;

    IF v_result_item_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Cannot use that item here'
        );
    END IF;

    -- For fishing, determine success (30% chance)
    IF v_terrain_type = 'OCEAN' AND v_item_type = 'FISHING_ROD' THEN
        v_fishing_success := (random() < 0.3);
        
        IF NOT v_fishing_success THEN
            RETURN jsonb_build_object(
                'success', true,
                'message', 'Nothing caught this time...'
            );
        END IF;
    END IF;

    -- Calculate random quantity
    IF v_min_quantity < 1 THEN v_min_quantity := 1; END IF;
    IF v_max_quantity < v_min_quantity THEN v_max_quantity := v_min_quantity; END IF;
    
    v_result_quantity := v_min_quantity + floor(random() * (v_max_quantity - v_min_quantity + 1))::integer;
    IF v_result_quantity < 1 THEN v_result_quantity := 1; END IF;

    -- Get max stack size for result item
    SELECT max_stack INTO v_max_stack
    FROM items
    WHERE id = v_result_item_id;

    -- First try to find an existing stack with space
    SELECT slot, quantity 
    INTO v_slot, v_current_quantity
    FROM player_inventory
    WHERE player_id = p_player_id 
    AND item_id = v_result_item_id
    AND quantity < v_max_stack
    ORDER BY slot
    LIMIT 1;

    -- Build debug info
    v_debug := jsonb_build_object(
        'current_quantity', v_current_quantity,
        'result_quantity', v_result_quantity,
        'max_stack', v_max_stack,
        'slot', v_slot,
        'item_id', v_result_item_id,
        'is_tool', v_is_tool
    );

    -- If no existing stack found, find an empty slot
    IF v_slot IS NULL THEN
        SELECT MIN(t.slot)
        INTO v_empty_slot
        FROM generate_series(1, 10) t(slot)
        WHERE NOT EXISTS (
            SELECT 1 
            FROM player_inventory pi 
            WHERE pi.player_id = p_player_id 
            AND pi.slot = t.slot
        );

        IF v_empty_slot IS NULL THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Inventory is full!'
            );
        END IF;

        -- Insert into empty slot
        INSERT INTO player_inventory (player_id, slot, item_id, quantity)
        VALUES (p_player_id, v_empty_slot, v_result_item_id, v_result_quantity);
    ELSE
        -- Calculate new quantity with bounds checking
        v_new_quantity := v_current_quantity + v_result_quantity;
        IF v_new_quantity > v_max_stack THEN 
            v_new_quantity := v_max_stack;
        END IF;
        IF v_new_quantity < 1 THEN
            v_new_quantity := 1;
        END IF;

        -- Update existing stack
        UPDATE player_inventory
        SET quantity = v_new_quantity
        WHERE player_id = p_player_id 
        AND slot = v_slot;
    END IF;

    -- Only consume non-tool items
    IF NOT v_is_tool THEN
        -- Remove one use from consumable items
        UPDATE player_inventory pi
        SET quantity = quantity - 1
        WHERE player_id = p_player_id 
        AND slot = p_item_slot
        AND quantity > 1;

        -- Delete the item if quantity is 1 (last use)
        DELETE FROM player_inventory
        WHERE player_id = p_player_id
        AND slot = p_item_slot
        AND quantity = 1;
    END IF;

    -- Return success message with quantity and item emoji, plus debug info
    RETURN jsonb_build_object(
        'success', true,
        'message', concat('+', v_result_quantity, ' ', v_result_item_emoji),
        'debug', v_debug
    );
END;
$$ LANGUAGE plpgsql; 