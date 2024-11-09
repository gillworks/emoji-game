CREATE OR REPLACE FUNCTION handle_item_action(
    p_player_id uuid,
    p_item_slot integer,
    p_x integer,
    p_y integer,
    p_server_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item_id text;
    v_terrain text;
    v_action item_terrain_actions%ROWTYPE;
    v_quantity integer;
    v_success boolean;
    v_target_slot integer;
BEGIN
    -- Get the item being used
    SELECT item_id INTO v_item_id
    FROM player_inventory
    WHERE player_id = p_player_id AND slot = p_item_slot;

    IF v_item_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'No item in selected slot');
    END IF;

    -- Get the terrain at the location
    SELECT terrain_type INTO v_terrain
    FROM map_data
    WHERE server_id = p_server_id AND x = p_x AND y = p_y;

    -- Find the action for this item-terrain combination (GATHER or TRANSFORM only)
    SELECT * INTO v_action
    FROM item_terrain_actions
    WHERE item_id = v_item_id AND terrain_type = v_terrain;

    IF v_action IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'No valid action for this item and terrain');
    END IF;

    -- Check if action succeeds based on success_rate
    v_success := random() < v_action.success_rate;
    
    IF v_success THEN
        -- Calculate random quantity
        v_quantity := floor(random() * (v_action.max_quantity - v_action.min_quantity + 1) + v_action.min_quantity)::integer;

        -- Find slot for result item (existing stack or empty slot)
        SELECT slot INTO v_target_slot
        FROM player_inventory
        WHERE player_id = p_player_id AND item_id = v_action.result_item_id
        UNION ALL
        SELECT generate_series AS slot
        FROM generate_series(1, 10)
        WHERE NOT EXISTS (
            SELECT 1 FROM player_inventory 
            WHERE player_id = p_player_id AND slot = generate_series
        )
        ORDER BY slot
        LIMIT 1;

        IF v_target_slot IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'Inventory full');
        END IF;

        -- Update inventory
        INSERT INTO player_inventory (player_id, slot, item_id, quantity)
        VALUES (p_player_id, v_target_slot, v_action.result_item_id, v_quantity)
        ON CONFLICT (player_id, slot)
        DO UPDATE SET quantity = player_inventory.quantity + v_quantity;

        -- If action type is TRANSFORM, update the terrain
        IF v_action.action_type = 'TRANSFORM' THEN
            UPDATE map_data
            SET terrain_type = 'EMPTY_FOREST'
            WHERE server_id = p_server_id AND x = p_x AND y = p_y;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'message', format('+%s %s', v_quantity, (SELECT emoji FROM items WHERE id = v_action.result_item_id))
        );
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'Action failed');
    END IF;
END;
$$;