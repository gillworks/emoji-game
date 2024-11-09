CREATE OR REPLACE FUNCTION handle_crafting(
    p_player_id UUID,
    p_recipe_id UUID,
    p_x INTEGER DEFAULT NULL,
    p_y INTEGER DEFAULT NULL,
    p_server_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_recipe crafting_recipes%ROWTYPE;
    v_ingredient RECORD;
    v_target_slot integer;
    v_missing_items text[];
    v_structure structures%ROWTYPE;
    v_current_terrain text;
    v_remaining_quantity integer;
    v_stack RECORD;
BEGIN
    -- Get the recipe
    SELECT * INTO v_recipe
    FROM crafting_recipes
    WHERE id = p_recipe_id;

    IF v_recipe IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invalid recipe');
    END IF;

    -- If this is a structure recipe, validate position parameters
    IF v_recipe.is_structure THEN
        IF p_x IS NULL OR p_y IS NULL OR p_server_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'Invalid build location');
        END IF;

        -- Get structure details
        SELECT * INTO v_structure
        FROM structures
        WHERE id = v_recipe.structure_id;

        -- Get current terrain
        SELECT terrain_type INTO v_current_terrain
        FROM map_data
        WHERE server_id = p_server_id AND x = p_x AND y = p_y;

        -- Check if we can build here
        IF v_current_terrain != v_structure.allowed_terrain THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', format('Cannot build %s here', v_structure.name)
            );
        END IF;
    END IF;

    -- Check if player has all required ingredients
    v_missing_items := ARRAY[]::text[];
    FOR v_ingredient IN (
        SELECT ci.item_id, ci.quantity_required, i.emoji
        FROM crafting_ingredients ci
        JOIN items i ON i.id = ci.item_id
        WHERE ci.recipe_id = p_recipe_id
    ) LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM (
                SELECT SUM(quantity) as total_quantity
                FROM player_inventory
                WHERE player_id = p_player_id
                AND item_id = v_ingredient.item_id
            ) sq
            WHERE total_quantity >= v_ingredient.quantity_required
        ) THEN
            v_missing_items := array_append(v_missing_items, 
                format('%s %s', v_ingredient.quantity_required, v_ingredient.emoji));
        END IF;
    END LOOP;

    IF array_length(v_missing_items, 1) > 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', format('Missing: %s', array_to_string(v_missing_items, ', '))
        );
    END IF;

    -- Remove ingredients
    FOR v_ingredient IN (
        SELECT item_id, quantity_required
        FROM crafting_ingredients
        WHERE recipe_id = p_recipe_id
    ) LOOP
        v_remaining_quantity := v_ingredient.quantity_required;
        
        -- Process each stack from smallest to largest until we've removed enough
        FOR v_stack IN (
            SELECT slot, quantity
            FROM player_inventory
            WHERE player_id = p_player_id
            AND item_id = v_ingredient.item_id
            AND quantity > 0
            ORDER BY quantity ASC
        ) LOOP
            IF v_remaining_quantity <= 0 THEN
                EXIT; -- We've removed enough
            END IF;

            IF v_stack.quantity <= v_remaining_quantity THEN
                -- Remove entire stack
                DELETE FROM player_inventory
                WHERE player_id = p_player_id
                AND slot = v_stack.slot;
                
                v_remaining_quantity := v_remaining_quantity - v_stack.quantity;
            ELSE
                -- Remove partial stack
                UPDATE player_inventory
                SET quantity = quantity - v_remaining_quantity
                WHERE player_id = p_player_id
                AND slot = v_stack.slot;
                
                v_remaining_quantity := 0;
            END IF;
        END LOOP;
    END LOOP;

    -- Handle structure building
    IF v_recipe.is_structure THEN
        -- Place the structure
        UPDATE map_data 
        SET 
            terrain_type = v_structure.terrain_type,
            metadata = jsonb_build_object(
                'structure_id', v_structure.id,
                'owner_id', p_player_id,
                'built_at', now()
            )
        WHERE server_id = p_server_id 
        AND x = p_x 
        AND y = p_y;

        RETURN jsonb_build_object(
            'success', true,
            'message', format('Built %s %s', v_structure.emoji, v_structure.name)
        );
    END IF;

    -- Handle regular item crafting
    -- Find slot for crafted item
    SELECT slot INTO v_target_slot
    FROM player_inventory
    WHERE player_id = p_player_id 
    AND item_id = v_recipe.result_item_id
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

    -- Add crafted item
    INSERT INTO player_inventory (player_id, slot, item_id, quantity)
    VALUES (p_player_id, v_target_slot, v_recipe.result_item_id, v_recipe.quantity_produced)
    ON CONFLICT (player_id, slot)
    DO UPDATE SET quantity = player_inventory.quantity + v_recipe.quantity_produced;

    RETURN jsonb_build_object(
        'success', true,
        'message', format('+%s %s', 
            v_recipe.quantity_produced, 
            (SELECT emoji FROM items WHERE id = v_recipe.result_item_id)
        )
    );
END;
$$ LANGUAGE plpgsql; 