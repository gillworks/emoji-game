-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

------------------------------------------
-- Core Tables
------------------------------------------

-- Players table
CREATE TABLE players (
    id UUID PRIMARY KEY,
    username TEXT NOT NULL,
    emoji TEXT DEFAULT '🐻',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Emoji choices table
CREATE TABLE emoji_choices (
    id SERIAL PRIMARY KEY,
    emoji TEXT NOT NULL,
    name TEXT NOT NULL,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Admin users table
CREATE TABLE admin_users (
    id UUID PRIMARY KEY REFERENCES players(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Game configs table
CREATE TABLE game_configs (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

------------------------------------------
-- Server System
------------------------------------------

-- Servers table
CREATE TABLE servers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_active TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    max_players INTEGER DEFAULT 100,
    map_width INTEGER NOT NULL DEFAULT 20,
    map_height INTEGER NOT NULL DEFAULT 20
);

-- Server players junction table
CREATE TABLE server_players (
    server_id UUID REFERENCES servers(id),
    player_id UUID REFERENCES players(id),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (server_id, player_id)
);

------------------------------------------
-- Map System
------------------------------------------

-- Terrain types table
CREATE TABLE terrain_types (
    id TEXT PRIMARY KEY,
    emoji TEXT NOT NULL,
    encounter TEXT,
    color TEXT NOT NULL DEFAULT 'rgba(255, 255, 255, 0.3)',
    spawn_items JSONB DEFAULT '[]'::jsonb
);

-- Map data table
CREATE TABLE map_data (
    server_id UUID REFERENCES servers(id),
    x INTEGER,
    y INTEGER,
    terrain_type TEXT NOT NULL,
    original_terrain_type TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    PRIMARY KEY (server_id, x, y),
    CONSTRAINT valid_terrain_types 
        CHECK (terrain_type IN ('FOREST', 'MOUNTAIN', 'PLAIN', 'OCEAN', 'EMPTY_FOREST', 'HOUSE', 'FARM', 'WORKSHOP', 'STORAGE_CHEST'))
);

-- Player positions table
CREATE TABLE player_positions (
    player_id UUID REFERENCES players(id),
    server_id UUID REFERENCES servers(id),
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (player_id, server_id)
);

------------------------------------------
-- Item System
------------------------------------------

-- Items table
CREATE TABLE items (
    id TEXT PRIMARY KEY,
    emoji TEXT NOT NULL,
    name TEXT NOT NULL,
    stackable BOOLEAN DEFAULT true,
    max_stack INTEGER DEFAULT 64,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Player inventory table
CREATE TABLE player_inventory (
    player_id UUID REFERENCES players(id),
    slot INTEGER CHECK (slot >= 1 AND slot <= 10),
    item_id TEXT REFERENCES items(id),
    quantity INTEGER DEFAULT 1 CHECK (quantity > 0),
    PRIMARY KEY (player_id, slot)
);

-- Item terrain actions table
CREATE TYPE item_action_type AS ENUM ('GATHER', 'TRANSFORM');

CREATE TABLE item_terrain_actions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    item_id TEXT REFERENCES items(id),
    terrain_type TEXT REFERENCES terrain_types(id),
    action_type item_action_type NOT NULL,
    result_item_id TEXT REFERENCES items(id),
    min_quantity INTEGER DEFAULT 1,
    max_quantity INTEGER DEFAULT 1,
    success_rate DECIMAL DEFAULT 1.0,
    hits_to_transform INTEGER,
    current_hits JSONB DEFAULT '{}'::jsonb,
    cooldown_seconds INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

------------------------------------------
-- Crafting System
------------------------------------------

-- Structures table
CREATE TABLE structures (
    id TEXT PRIMARY KEY,
    emoji TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    terrain_type TEXT NOT NULL REFERENCES terrain_types(id),
    allowed_terrain TEXT NOT NULL REFERENCES terrain_types(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Crafting recipes table
CREATE TABLE crafting_recipes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    result_item_id TEXT REFERENCES items(id),
    structure_id TEXT REFERENCES structures(id),
    is_structure BOOLEAN DEFAULT false,
    quantity_produced INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Crafting ingredients table
CREATE TABLE crafting_ingredients (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    recipe_id UUID REFERENCES crafting_recipes(id),
    item_id TEXT REFERENCES items(id),
    quantity_required INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

------------------------------------------
-- Resource System
------------------------------------------

-- Resource spawns table
CREATE TABLE resource_spawns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID REFERENCES servers(id),
    x INTEGER,
    y INTEGER,
    item_id TEXT REFERENCES items(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (server_id, x, y)
);

------------------------------------------
-- Storage System
------------------------------------------

CREATE TABLE storage_inventories (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    server_id uuid REFERENCES servers(id),
    x integer,
    y integer,
    slot integer CHECK (slot >= 1 AND slot <= 20),
    item_id text REFERENCES items(id),
    quantity integer CHECK (quantity > 0),
    created_at timestamp with time zone DEFAULT now(),
    FOREIGN KEY (server_id, x, y) REFERENCES map_data(server_id, x, y),
    UNIQUE (server_id, x, y, slot)
);

------------------------------------------
-- Indexes
------------------------------------------

CREATE INDEX idx_player_positions_player_server ON player_positions(player_id, server_id);
CREATE INDEX idx_player_positions_server ON player_positions(server_id);
CREATE INDEX idx_server_players_server ON server_players(server_id);
CREATE INDEX idx_server_players_combined ON server_players(server_id, player_id);

------------------------------------------
-- Functions
------------------------------------------

-- Server Management Functions
CREATE OR REPLACE FUNCTION increment_server_players(server_id UUID)
RETURNS void AS $$
BEGIN
    -- Check if server exists and get max_players
    DECLARE
        max_players_limit INTEGER;
        current_count INTEGER;
    BEGIN
        SELECT max_players INTO max_players_limit FROM servers WHERE id = server_id;
        
        -- Count current players
        SELECT COUNT(*) INTO current_count 
        FROM server_players 
        WHERE server_players.server_id = increment_server_players.server_id;

        -- Verify we haven't exceeded max_players
        IF current_count >= max_players_limit THEN
            RAISE EXCEPTION 'Server is full';
        END IF;
    END;

    -- Update last_active timestamp
    UPDATE servers 
    SET last_active = NOW()
    WHERE id = server_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION decrement_server_players(server_id UUID)
RETURNS void AS $$
BEGIN
    -- Just update the last_active timestamp
    UPDATE servers 
    SET last_active = NOW()
    WHERE id = server_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Cleanup Functions
CREATE OR REPLACE FUNCTION cleanup_inactive_servers()
RETURNS void AS $$
BEGIN
    -- Delete servers that have been inactive for more than 1 hour and have no players
    DELETE FROM servers
    WHERE id IN (
        SELECT s.id 
        FROM servers s
        LEFT JOIN server_players sp ON s.id = sp.server_id
        WHERE s.last_active < NOW() - INTERVAL '1 hour'
        GROUP BY s.id
        HAVING COUNT(sp.player_id) = 0
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION cleanup_player(player_id UUID, server_id UUID)
RETURNS void AS $$
BEGIN
  -- Delete the player's position
  DELETE FROM player_positions 
  WHERE player_positions.player_id = cleanup_player.player_id 
  AND player_positions.server_id = cleanup_player.server_id;

  -- Delete from server_players
  DELETE FROM server_players
  WHERE server_players.player_id = cleanup_player.player_id
  AND server_players.server_id = cleanup_player.server_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION handle_cleanup_request()
RETURNS void AS $$
BEGIN
  -- Get the player_id from the current session
  PERFORM cleanup_player(auth.uid(), server_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Resource Management Functions
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

-- Item Action Functions
CREATE OR REPLACE FUNCTION handle_item_action(
    p_player_id uuid,
    p_item_slot integer,
    p_x integer,
    p_y integer,
    p_server_id uuid
)
RETURNS jsonb AS $$
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
    WHERE pi.player_id = p_player_id AND pi.slot = p_item_slot
    LIMIT 1;  -- Add LIMIT 1 to ensure we only get one row

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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Crafting Functions
CREATE OR REPLACE FUNCTION handle_crafting(
    p_player_id uuid,
    p_recipe_id uuid,
    p_x integer DEFAULT NULL,
    p_y integer DEFAULT NULL,
    p_server_id uuid DEFAULT NULL
)
RETURNS jsonb AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Resource Collection Function
CREATE OR REPLACE FUNCTION collect_resource(
    p_player_id uuid,
    p_server_id uuid,
    p_x integer,
    p_y integer
)
RETURNS jsonb AS $$
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

-- Map Reset Function
CREATE OR REPLACE FUNCTION reset_server_map(server_id_param uuid)
RETURNS void AS $$
DECLARE
    v_x integer;
    v_y integer;
BEGIN
    -- Reset terrain to original state
    UPDATE map_data 
    SET terrain_type = original_terrain_type,
        metadata = NULL
    WHERE server_id = server_id_param;

    -- Clear existing resources
    DELETE FROM resource_spawns 
    WHERE server_id = server_id_param;

    -- Attempt initial resource spawns for each tile
    FOR v_x IN 0..(SELECT map_width - 1 FROM servers WHERE id = server_id_param) LOOP
        FOR v_y IN 0..(SELECT map_height - 1 FROM servers WHERE id = server_id_param) LOOP
            PERFORM try_spawn_resource(server_id_param, v_x, v_y);
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Inventory Movement Function
CREATE OR REPLACE FUNCTION move_inventory_item(
    p_player_id uuid,
    p_from_slot integer,
    p_to_slot integer
)
RETURNS jsonb AS $$
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

-- Periodic Resource Spawning Function
CREATE OR REPLACE FUNCTION spawn_resources_periodically(
    p_server_id uuid,
    p_chance float DEFAULT 0.1
)
RETURNS void AS $$
DECLARE
    v_config jsonb;
    v_x integer;
    v_y integer;
BEGIN
    -- Check if spawning is enabled
    SELECT value INTO v_config
    FROM game_configs
    WHERE key = 'resource_spawning';

    -- Exit if spawning is disabled
    IF NOT (v_config->>'enabled')::boolean THEN
        RETURN;
    END IF;

    -- Use configured chance if available
    IF v_config ? 'spawn_chance' THEN
        p_chance := (v_config->>'spawn_chance')::float;
    END IF;

    -- Rest of function remains the same...
    FOR v_x, v_y IN 
        SELECT x, y 
        FROM map_data md
        WHERE md.server_id = p_server_id
        AND NOT EXISTS (
            SELECT 1 
            FROM resource_spawns rs 
            WHERE rs.server_id = p_server_id 
            AND rs.x = md.x 
            AND rs.y = md.y
        )
    LOOP
        IF random() < p_chance THEN
            PERFORM try_spawn_resource(p_server_id, v_x, v_y);
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Storage Function
CREATE OR REPLACE FUNCTION handle_storage_action(
    p_player_id uuid,
    p_server_id uuid,
    p_x integer,
    p_y integer,
    p_action storage_action,
    p_storage_slot integer,
    p_inventory_slot integer,
    p_quantity integer DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
    v_structure_owner uuid;
    v_item_id text;
    v_current_quantity integer;
    v_max_stack integer;
    v_item_emoji text;
    v_item_name text;
    v_target_item_id text;
    v_target_quantity integer;
    v_final_quantity integer;
    v_temp_item_id text;
    v_temp_quantity integer;
BEGIN
    -- Check structure ownership and type
    SELECT (metadata->>'owner_id')::uuid
    INTO v_structure_owner
    FROM map_data
    WHERE server_id = p_server_id
    AND x = p_x
    AND y = p_y
    AND metadata->>'structure_id' = 'STORAGE_CHEST';

    IF v_structure_owner IS NULL OR v_structure_owner != p_player_id THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'You don''t own this storage chest'
        );
    END IF;

    -- Get items from both slots
    SELECT item_id, quantity INTO v_item_id, v_current_quantity
    FROM player_inventory
    WHERE player_id = p_player_id AND slot = p_inventory_slot;

    SELECT item_id, quantity INTO v_target_item_id, v_target_quantity
    FROM storage_inventories
    WHERE server_id = p_server_id 
    AND x = p_x 
    AND y = p_y 
    AND slot = p_storage_slot;

    -- Handle deposit
    IF p_action = 'DEPOSIT' THEN
        IF v_item_id IS NULL THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'No item in selected inventory slot'
            );
        END IF;

        -- If target slot has a different item, perform swap
        IF v_target_item_id IS NOT NULL AND v_target_item_id != v_item_id THEN
            -- Store target item temporarily
            v_temp_item_id := v_target_item_id;
            v_temp_quantity := v_target_quantity;

            -- Move inventory item to storage
            INSERT INTO storage_inventories (server_id, x, y, slot, item_id, quantity)
            VALUES (p_server_id, p_x, p_y, p_storage_slot, v_item_id, v_current_quantity)
            ON CONFLICT (server_id, x, y, slot)
            DO UPDATE SET 
                item_id = v_item_id,
                quantity = v_current_quantity;

            -- Move storage item to inventory
            UPDATE player_inventory
            SET item_id = v_temp_item_id,
                quantity = v_temp_quantity
            WHERE player_id = p_player_id AND slot = p_inventory_slot;

            RETURN jsonb_build_object(
                'success', true,
                'message', 'Items swapped successfully'
            );
        END IF;

        -- Normal deposit logic for same item or empty slot
        -- Get max stack size
        SELECT max_stack INTO v_max_stack
        FROM items
        WHERE id = v_item_id;

        -- Calculate quantity to deposit
        v_current_quantity := LEAST(v_current_quantity, COALESCE(p_quantity, v_current_quantity));

        -- If target slot has same item, check stack limit
        IF v_target_item_id = v_item_id THEN
            v_current_quantity := LEAST(v_current_quantity, v_max_stack - COALESCE(v_target_quantity, 0));
        END IF;

        IF v_current_quantity <= 0 THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Cannot deposit zero or negative quantity'
            );
        END IF;

        -- First, insert or update storage inventory
        INSERT INTO storage_inventories (server_id, x, y, slot, item_id, quantity)
        VALUES (p_server_id, p_x, p_y, p_storage_slot, v_item_id, 
            CASE 
                WHEN v_target_item_id = v_item_id THEN v_current_quantity + COALESCE(v_target_quantity, 0)
                ELSE v_current_quantity
            END)
        ON CONFLICT (server_id, x, y, slot)
        DO UPDATE SET 
            quantity = CASE 
                WHEN storage_inventories.item_id = v_item_id THEN storage_inventories.quantity + v_current_quantity
                ELSE v_current_quantity
            END,
            item_id = v_item_id;

        -- Then handle player inventory in a single step
        IF v_current_quantity = v_current_quantity THEN
            -- If we're moving the entire stack, just delete it
            DELETE FROM player_inventory
            WHERE player_id = p_player_id AND slot = p_inventory_slot;
        ELSE
            -- Otherwise update the quantity
            UPDATE player_inventory
            SET quantity = quantity - v_current_quantity
            WHERE player_id = p_player_id AND slot = p_inventory_slot;
        END IF;

    -- Handle withdraw
    ELSIF p_action = 'WITHDRAW' THEN
        IF v_target_item_id IS NULL THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'No item in selected storage slot'
            );
        END IF;

        -- If inventory slot has a different item, perform swap
        IF v_item_id IS NOT NULL AND v_item_id != v_target_item_id THEN
            -- Store inventory item temporarily
            v_temp_item_id := v_item_id;
            v_temp_quantity := v_current_quantity;

            -- Move storage item to inventory
            UPDATE player_inventory
            SET item_id = v_target_item_id,
                quantity = v_target_quantity
            WHERE player_id = p_player_id AND slot = p_inventory_slot;

            -- Move inventory item to storage
            INSERT INTO storage_inventories (server_id, x, y, slot, item_id, quantity)
            VALUES (p_server_id, p_x, p_y, p_storage_slot, v_temp_item_id, v_temp_quantity)
            ON CONFLICT (server_id, x, y, slot)
            DO UPDATE SET 
                item_id = v_temp_item_id,
                quantity = v_temp_quantity;

            RETURN jsonb_build_object(
                'success', true,
                'message', 'Items swapped successfully'
            );
        END IF;

        -- Normal withdraw logic for same item or empty slot
        -- Get item details
        SELECT emoji, name, max_stack
        INTO v_item_emoji, v_item_name, v_max_stack
        FROM items
        WHERE id = v_target_item_id;

        -- Calculate quantity to withdraw
        v_current_quantity := LEAST(v_target_quantity, COALESCE(p_quantity, v_target_quantity));

        -- If inventory slot has same item, check stack limit
        IF v_item_id = v_target_item_id THEN
            v_current_quantity := LEAST(v_current_quantity, v_max_stack - COALESCE(v_current_quantity, 0));
        END IF;

        v_final_quantity := CASE 
            WHEN v_item_id = v_target_item_id THEN v_current_quantity + COALESCE(v_current_quantity, 0)
            ELSE v_current_quantity
        END;

        IF v_current_quantity <= 0 OR v_final_quantity <= 0 THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Cannot withdraw zero or negative quantity'
            );
        END IF;

        -- First add to player inventory
        INSERT INTO player_inventory (player_id, slot, item_id, quantity)
        VALUES (p_player_id, p_inventory_slot, v_target_item_id, v_current_quantity)
        ON CONFLICT (player_id, slot)
        DO UPDATE SET 
            quantity = CASE 
                WHEN player_inventory.item_id = v_target_item_id THEN player_inventory.quantity + v_current_quantity
                ELSE v_current_quantity
            END,
            item_id = v_target_item_id;

        -- Then handle storage inventory in a single step
        IF v_current_quantity = v_target_quantity THEN
            -- If we're withdrawing the entire stack, just delete it
            DELETE FROM storage_inventories
            WHERE server_id = p_server_id 
            AND x = p_x 
            AND y = p_y 
            AND slot = p_storage_slot;
        ELSE
            -- Otherwise update the quantity
            UPDATE storage_inventories
            SET quantity = quantity - v_current_quantity
            WHERE server_id = p_server_id 
            AND x = p_x 
            AND y = p_y 
            AND slot = p_storage_slot;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', format('Successfully %s %s %s', 
            CASE p_action 
                WHEN 'DEPOSIT' THEN 'deposited'
                ELSE 'withdrawn'
            END,
            v_current_quantity,
            COALESCE(v_item_name, 'items')
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

------------------------------------------
-- RLS Policies
------------------------------------------

-- Enable RLS on all tables
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE emoji_choices ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE servers ENABLE ROW LEVEL SECURITY;
ALTER TABLE server_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE terrain_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE map_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_terrain_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE structures ENABLE ROW LEVEL SECURITY;
ALTER TABLE crafting_recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE crafting_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE resource_spawns ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage_inventories ENABLE ROW LEVEL SECURITY;

-- Players policies
CREATE POLICY "Users can insert their own player record"
    ON players FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own player record"
    ON players FOR UPDATE
    TO authenticated
    USING (auth.uid() = id);

CREATE POLICY "Users can view all player records"
    ON players FOR SELECT
    TO authenticated
    USING (true);

-- Emoji choices policies
CREATE POLICY "Authenticated users can view emoji choices" 
    ON emoji_choices FOR SELECT 
    TO authenticated
    USING (true);

-- Admin users policies
CREATE POLICY "Admin users are viewable by authenticated users"
    ON admin_users FOR SELECT
    TO authenticated
    USING (true);

-- Game configs policies
CREATE POLICY "Configs are readable by all authenticated users"
    ON game_configs FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Only admins can modify configs"
    ON game_configs FOR ALL
    TO authenticated
    USING (auth.uid() IN (SELECT id FROM admin_users));

-- Servers policies
CREATE POLICY "Allow anonymous users to create servers"
    ON servers FOR INSERT
    TO anon
    WITH CHECK (true);

CREATE POLICY "Allow anonymous users to read servers"
    ON servers FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "Servers are viewable by all authenticated users"
    ON servers FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated users can create servers"
    ON servers FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Server players policies
CREATE POLICY "Server players is viewable by all authenticated users"
    ON server_players FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Players can join servers"
    ON server_players FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = player_id);

CREATE POLICY "Players can leave servers"
    ON server_players FOR DELETE
    TO authenticated
    USING (auth.uid() = player_id);

-- Map data policies
CREATE POLICY "Allow anonymous users to insert map data"
    ON map_data FOR INSERT
    TO anon
    WITH CHECK (true);

CREATE POLICY "Allow anonymous users to read map data"
    ON map_data FOR SELECT
    TO anon
    USING (true);

CREATE POLICY "Map data can be inserted by authenticated users"
    ON map_data FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Map data can be updated by authenticated users"
    ON map_data FOR UPDATE
    TO authenticated
    USING (true);

CREATE POLICY "Map data is viewable by all authenticated users"
    ON map_data FOR SELECT
    TO authenticated
    USING (true);

-- Player positions policies
CREATE POLICY "Players can insert their own position"
    ON player_positions FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = player_id);

CREATE POLICY "Players can update their own position"
    ON player_positions FOR UPDATE
    TO authenticated
    USING (auth.uid() = player_id)
    WITH CHECK (auth.uid() = player_id);

CREATE POLICY "Players can delete their own position"
    ON player_positions FOR DELETE
    TO authenticated
    USING (auth.uid() = player_id);

CREATE POLICY "All players can view positions"
    ON player_positions FOR SELECT
    TO authenticated
    USING (true);

-- Items policies
CREATE POLICY "Items are viewable by everyone"
    ON items FOR SELECT
    TO authenticated
    USING (true);

-- Player inventory policies
CREATE POLICY "Players can view their own inventory"
    ON player_inventory FOR SELECT
    TO authenticated
    USING (auth.uid() = player_id);

CREATE POLICY "Players can insert into their own inventory"
    ON player_inventory FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = player_id);

CREATE POLICY "Players can update their own inventory"
    ON player_inventory FOR UPDATE
    TO authenticated
    USING (auth.uid() = player_id)
    WITH CHECK (auth.uid() = player_id);

CREATE POLICY "Players can delete from their own inventory"
    ON player_inventory FOR DELETE
    TO authenticated
    USING (auth.uid() = player_id);

-- Item terrain actions policies
CREATE POLICY "Item actions are viewable by everyone"
    ON item_terrain_actions FOR SELECT
    TO authenticated
    USING (true);

-- Structures policies
CREATE POLICY "Structures are viewable by everyone"
    ON structures FOR SELECT
    TO authenticated
    USING (true);

-- Crafting policies
CREATE POLICY "Recipes are viewable by everyone"
    ON crafting_recipes FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Ingredients are viewable by everyone"
    ON crafting_ingredients FOR SELECT
    TO authenticated
    USING (true);

-- Resource spawns policies
CREATE POLICY "Resources are viewable by all authenticated users"
    ON resource_spawns FOR SELECT
    TO authenticated
    USING (true);

-- Storage inventories policies
CREATE POLICY "Storage contents are viewable by all authenticated users" ON storage_inventories
    FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Storage contents can only be modified by structure owner" ON storage_inventories
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM map_data
            WHERE map_data.server_id = storage_inventories.server_id
            AND map_data.x = storage_inventories.x
            AND map_data.y = storage_inventories.y
            AND (map_data.metadata->>'owner_id')::uuid = auth.uid()
        )
    );

------------------------------------------
-- Initial Data
------------------------------------------

-- Insert terrain types
INSERT INTO terrain_types (id, emoji, encounter, color, spawn_items) VALUES
    ('FOREST', '🌳', '🐺', 'rgba(76, 175, 80, 0.3)', '[
        {"item_id": "MUSHROOM", "chance": 0.05},
        {"item_id": "WOOD", "chance": 0.15}
    ]'::jsonb),
    ('MOUNTAIN', '🏔️', '🐆', 'rgba(158, 158, 158, 0.3)', '[
        {"item_id": "STONE", "chance": 0.2},
        {"item_id": "CRYSTAL", "chance": 0.05}
    ]'::jsonb),
    ('PLAIN', '🌱', null, 'rgba(139, 195, 74, 0.3)', '[
        {"item_id": "STONE", "chance": 0.15}
    ]'::jsonb),
    ('OCEAN', '🌊', '🦈', 'rgba(33, 150, 243, 0.3)', '[]'::jsonb),
    ('EMPTY_FOREST', '🌱', null, 'rgba(76, 175, 80, 0.3)', '[]'::jsonb),
    ('HOUSE', '🏠', null, 'rgba(139, 69, 19, 0.3)', '[]'::jsonb),
    ('FARM', '🌾', null, 'rgba(124, 252, 0, 0.3)', '[]'::jsonb),
    ('WORKSHOP', '🏭', null, 'rgba(169, 169, 169, 0.3)', '[]'::jsonb),
    ('STORAGE_CHEST', '📦', 'rgba(139, 69, 19, 0.3)', NULL, '[]'::jsonb);

-- Insert items
INSERT INTO items (id, emoji, name, stackable, max_stack) VALUES
    ('AXE', '🪓', 'Axe', false, 1),
    ('WOOD', '🪵', 'Wood', true, 64),
    ('PICKAXE', '⛏️', 'Pickaxe', false, 1),
    ('STONE', '🪨', 'Stone', true, 64),
    ('FISHING_ROD', '🎣', 'Fishing Rod', false, 1),
    ('FISH', '🐟', 'Fish', true, 64),
    ('MUSHROOM', '🍄', 'Mushroom', true, 64),
    ('CRYSTAL', '💎', 'Crystal', true, 64);

-- Insert item terrain actions
INSERT INTO item_terrain_actions 
    (item_id, terrain_type, action_type, result_item_id, min_quantity, max_quantity, success_rate, hits_to_transform)
VALUES
    ('AXE', 'FOREST', 'GATHER', 'WOOD', 1, 3, 1.0, 3),
    ('PICKAXE', 'MOUNTAIN', 'GATHER', 'STONE', 1, 2, 0.8, null),
    ('FISHING_ROD', 'OCEAN', 'GATHER', 'FISH', 0, 1, 0.6, null);

-- Insert structures
INSERT INTO structures (id, emoji, name, description, terrain_type, allowed_terrain) VALUES
    ('HOUSE', '🏠', 'House', 'A cozy shelter', 'HOUSE', 'PLAIN'),
    ('FARM', '🌾', 'Farm', 'Grows food', 'FARM', 'PLAIN'),
    ('WORKSHOP', '🏭', 'Workshop', 'Crafting station', 'WORKSHOP', 'PLAIN'),
    ('STORAGE_CHEST', '📦', 'Storage Chest', 'Store items securely', 'STORAGE_CHEST', 'PLAIN');

-- Insert crafting recipes
WITH recipes AS (
    INSERT INTO crafting_recipes (id, result_item_id, quantity_produced) VALUES
        ('2773dcb5-d668-4b0f-9876-d6a0d2e6c525', 'AXE', 1),
        ('7c228a4d-df53-4f93-9e41-f3f62c0607f3', 'FISHING_ROD', 1),
        ('9a7b6c5d-4e3f-2d1c-8b9a-0f1e2d3c4b5a', 'PICKAXE', 1)
    RETURNING id
),
house_recipe AS (
    INSERT INTO crafting_recipes (structure_id, is_structure, quantity_produced)
    VALUES ('HOUSE', true, 1)
    RETURNING id
)
-- Insert recipe ingredients
INSERT INTO crafting_ingredients (recipe_id, item_id, quantity_required)
SELECT r.id, i.item_id, i.quantity
FROM recipes r
CROSS JOIN (VALUES
    ('2773dcb5-d668-4b0f-9876-d6a0d2e6c525', 'WOOD', 2),
    ('2773dcb5-d668-4b0f-9876-d6a0d2e6c525', 'STONE', 1),
    ('7c228a4d-df53-4f93-9e41-f3f62c0607f3', 'WOOD', 3),
    ('9a7b6c5d-4e3f-2d1c-8b9a-0f1e2d3c4b5a', 'WOOD', 2),
    ('9a7b6c5d-4e3f-2d1c-8b9a-0f1e2d3c4b5a', 'STONE', 2)
) AS i(recipe_id, item_id, quantity)
WHERE r.id = i.recipe_id
UNION ALL
SELECT house_recipe.id, item_id, quantity
FROM house_recipe, (VALUES 
    ('WOOD', 10),
    ('STONE', 5)
) AS ingredients(item_id, quantity);

-- Insert emoji choices
INSERT INTO emoji_choices (emoji, name) VALUES
    ('🐻', 'Bear'),
    ('🐸', 'Frog'),
    ('🐵', 'Monkey'),
    ('🐨', 'Koala'),
    ('🐷', 'Pig');

-- Insert default game configs
INSERT INTO game_configs (key, value) VALUES
    ('encounter_rates', '{
        "FOREST": 0.3,
        "MOUNTAIN": 0.4,
        "PLAIN": 0.2,
        "OCEAN": 0.3,
        "EMPTY_FOREST": 0.0
    }'::jsonb),
    ('resource_spawning', '{
        "enabled": true,
        "spawn_chance": 0.1,
        "spawn_interval": 300
    }'::jsonb);

-- Insert storage chest recipe
WITH storage_recipe AS (
    INSERT INTO crafting_recipes (id, structure_id, is_structure, quantity_produced)
    VALUES (gen_random_uuid(), 'STORAGE_CHEST', true, 1)
    RETURNING id
)
INSERT INTO crafting_ingredients (recipe_id, item_id, quantity_required)
SELECT storage_recipe.id, item_id, quantity
FROM storage_recipe, (VALUES 
    ('WOOD', 4),
    ('STONE', 2)
) AS ingredients(item_id, quantity);

------------------------------------------
-- Enable Realtime
------------------------------------------

ALTER PUBLICATION supabase_realtime ADD TABLE player_positions; 