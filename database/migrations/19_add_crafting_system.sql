-- Create crafting tables
CREATE TABLE crafting_recipes (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    result_item_id text REFERENCES items(id),
    quantity_produced integer DEFAULT 1,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

CREATE TABLE crafting_ingredients (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    recipe_id uuid REFERENCES crafting_recipes(id),
    item_id text REFERENCES items(id),
    quantity_required integer DEFAULT 1,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

-- Add RLS policies
ALTER TABLE crafting_recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE crafting_ingredients ENABLE ROW LEVEL SECURITY;

-- Everyone can view recipes and ingredients
CREATE POLICY "Recipes are viewable by everyone" ON crafting_recipes
    FOR SELECT USING (true);

CREATE POLICY "Ingredients are viewable by everyone" ON crafting_ingredients
    FOR SELECT USING (true);

-- Create function to handle crafting
CREATE OR REPLACE FUNCTION handle_crafting(
    p_player_id uuid,
    p_recipe_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_recipe crafting_recipes%ROWTYPE;
    v_ingredient RECORD;
    v_target_slot integer;
    v_missing_items text[];
BEGIN
    -- Get the recipe
    SELECT * INTO v_recipe
    FROM crafting_recipes
    WHERE id = p_recipe_id;

    IF v_recipe IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invalid recipe');
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
            FROM player_inventory
            WHERE player_id = p_player_id
            AND item_id = v_ingredient.item_id
            AND quantity >= v_ingredient.quantity_required
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

    -- Remove ingredients (in a transaction)
    FOR v_ingredient IN (
        SELECT item_id, quantity_required
        FROM crafting_ingredients
        WHERE recipe_id = p_recipe_id
    ) LOOP
        UPDATE player_inventory
        SET quantity = quantity - v_ingredient.quantity_required
        WHERE player_id = p_player_id
        AND item_id = v_ingredient.item_id
        AND quantity >= v_ingredient.quantity_required;

        -- Remove items with 0 quantity
        DELETE FROM player_inventory
        WHERE player_id = p_player_id
        AND item_id = v_ingredient.item_id
        AND quantity <= 0;
    END LOOP;

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
$$;

-- Insert some example recipes
INSERT INTO crafting_recipes (id, result_item_id, quantity_produced) VALUES
    ('2773dcb5-d668-4b0f-9876-d6a0d2e6c525', 'AXE', 1),
    ('7c228a4d-df53-4f93-9e41-f3f62c0607f3', 'FISHING_ROD', 1);

-- Insert recipe ingredients
INSERT INTO crafting_ingredients (recipe_id, item_id, quantity_required) VALUES
    ('2773dcb5-d668-4b0f-9876-d6a0d2e6c525', 'WOOD', 2),  -- Axe requires 2 wood
    ('2773dcb5-d668-4b0f-9876-d6a0d2e6c525', 'STONE', 1), -- and 1 stone
    ('7c228a4d-df53-4f93-9e41-f3f62c0607f3', 'WOOD', 3);  -- Fishing rod requires 3 wood 