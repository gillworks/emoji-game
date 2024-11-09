-- Add columns to track transformation hits
ALTER TABLE item_terrain_actions 
    ADD COLUMN hits_to_transform integer,
    ADD COLUMN current_hits jsonb DEFAULT '{}'::jsonb;

-- Update the procedure to handle hit tracking
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
    v_current_hits integer;
    v_location_key text;
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

    -- Find the action for this item-terrain combination
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

        -- Handle transformation hits if configured
        IF v_action.hits_to_transform IS NOT NULL THEN
            -- Create a unique key for this location
            v_location_key := format('%s_%s_%s', p_server_id, p_x, p_y);
            
            -- Get current hits for this location
            v_current_hits := COALESCE((v_action.current_hits->v_location_key)::integer, 0) + 1;
            
            -- Update the hits counter
            UPDATE item_terrain_actions
            SET current_hits = jsonb_set(
                COALESCE(current_hits, '{}'::jsonb),
                array[v_location_key],
                to_jsonb(v_current_hits)
            )
            WHERE id = v_action.id;

            -- If we've reached the required hits, transform the terrain
            IF v_current_hits >= v_action.hits_to_transform THEN
                -- Reset hits for this location
                UPDATE item_terrain_actions
                SET current_hits = current_hits - v_location_key
                WHERE id = v_action.id;

                -- Transform the terrain
                UPDATE map_data
                SET terrain_type = 'EMPTY_FOREST'
                WHERE server_id = p_server_id AND x = p_x AND y = p_y;
            END IF;
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

-- Update the axe action to require 3 hits
UPDATE item_terrain_actions 
SET hits_to_transform = 3
WHERE item_id = 'AXE' AND terrain_type = 'FOREST'; 