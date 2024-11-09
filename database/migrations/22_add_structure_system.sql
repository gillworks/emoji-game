-- Allow null encounters in terrain_types
ALTER TABLE terrain_types ALTER COLUMN encounter DROP NOT NULL;

-- First, drop the existing constraint
ALTER TABLE map_data DROP CONSTRAINT IF EXISTS valid_terrain_types;

-- Add corresponding terrain types for structures FIRST
INSERT INTO terrain_types (id, emoji, encounter, color) VALUES
    ('HOUSE', '🏠', null, 'rgba(139, 69, 19, 0.3)'),
    ('FARM', '🌾', null, 'rgba(124, 252, 0, 0.3)'),
    ('WORKSHOP', '🏭', null, 'rgba(169, 169, 169, 0.3)');

-- Re-create the constraint with the new terrain types
ALTER TABLE map_data ADD CONSTRAINT valid_terrain_types 
    CHECK (terrain_type IN ('FOREST', 'MOUNTAIN', 'PLAIN', 'OCEAN', 'EMPTY_FOREST', 'HOUSE', 'FARM', 'WORKSHOP'));

-- Add structures table to define different types of structures
CREATE TABLE structures (
    id text PRIMARY KEY,
    emoji text NOT NULL,
    name text NOT NULL,
    description text,
    terrain_type text NOT NULL REFERENCES terrain_types(id), -- The terrain type it becomes when built
    allowed_terrain text NOT NULL REFERENCES terrain_types(id), -- The terrain type it can be built on
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

-- Enable RLS
ALTER TABLE structures ENABLE ROW LEVEL SECURITY;

-- Add viewing policies
CREATE POLICY "Structures are viewable by everyone" ON structures
    FOR SELECT USING (true);

-- THEN add the structures that reference these terrain types
INSERT INTO structures (id, emoji, name, description, terrain_type, allowed_terrain) VALUES
    ('HOUSE', '🏠', 'House', 'A cozy shelter', 'HOUSE', 'PLAIN'),
    ('FARM', '🌾', 'Farm', 'Grows food', 'FARM', 'PLAIN'),
    ('WORKSHOP', '🏭', 'Workshop', 'Crafting station', 'WORKSHOP', 'PLAIN');

-- Add structures as items so they show up in crafting menu
INSERT INTO items (id, emoji, name) 
SELECT id, emoji, name FROM structures;

-- Modify crafting_recipes to support direct building
ALTER TABLE crafting_recipes 
ADD COLUMN structure_id text REFERENCES structures(id),
ADD COLUMN is_structure boolean DEFAULT false;

-- Add metadata column to map_data for structure info if not exists
ALTER TABLE map_data 
ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- Drop the old function first to avoid overloading issues
DROP FUNCTION IF EXISTS handle_crafting(uuid, uuid);

-- Modify the handle_crafting function to support direct building
CREATE OR REPLACE FUNCTION handle_crafting(
    p_player_id uuid,
    p_recipe_id uuid,
    p_x integer DEFAULT NULL,
    p_y integer DEFAULT NULL,
    p_server_id uuid DEFAULT NULL
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
    v_structure structures%ROWTYPE;
    v_current_terrain text;
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

    -- Remove ingredients
    FOR v_ingredient IN (
        SELECT item_id, quantity_required
        FROM crafting_ingredients
        WHERE recipe_id = p_recipe_id
    ) LOOP
        UPDATE player_inventory
        SET quantity = quantity - v_ingredient.quantity_required
        WHERE player_id = p_player_id
        AND item_id = v_ingredient.item_id;

        -- Remove empty stacks
        DELETE FROM player_inventory
        WHERE player_id = p_player_id
        AND item_id = v_ingredient.item_id
        AND quantity <= 0;
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

    -- Handle regular item crafting (existing logic)
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
$$;

-- Add example structure recipes
WITH house_recipe AS (
    INSERT INTO crafting_recipes (structure_id, is_structure, quantity_produced)
    VALUES ('HOUSE', true, 1)
    RETURNING id
)
INSERT INTO crafting_ingredients (recipe_id, item_id, quantity_required)
SELECT house_recipe.id, item_id, quantity_required
FROM house_recipe, (VALUES 
    ('WOOD', 10),
    ('STONE', 5)
) AS ingredients(item_id, quantity_required); 