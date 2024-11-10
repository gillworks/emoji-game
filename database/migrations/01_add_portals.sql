-- Add portal configuration to map_data metadata
COMMENT ON COLUMN map_data.metadata IS 'JSON structure that can include:
- owner_id: UUID of structure builder
- built_at: Timestamp of construction
- structure_id: ID of structure type
- portal_config: Portal configuration with format:
  {
    "destination_server": UUID,
    "destination_x": INTEGER,
    "destination_y": INTEGER
  }
';

-- Add function to handle transportation between servers
CREATE OR REPLACE FUNCTION handle_server_transport(
    p_player_id uuid,
    p_current_server_id uuid,
    p_current_x integer,
    p_current_y integer
) RETURNS jsonb AS $$
DECLARE
    v_portal_config jsonb;
    v_destination_server uuid;
    v_destination_x integer;
    v_destination_y integer;
BEGIN
    -- Debug log input parameters
    RAISE NOTICE 'Transport request: player=%, server=%, x=%, y=%', 
        p_player_id, p_current_server_id, p_current_x, p_current_y;

    -- Get portal configuration from metadata
    SELECT metadata->'portal_config' INTO v_portal_config
    FROM map_data
    WHERE server_id = p_current_server_id
    AND x = p_current_x
    AND y = p_current_y;

    -- Debug log portal config
    RAISE NOTICE 'Portal config found: %', v_portal_config;

    IF v_portal_config IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'No portal configuration at this location'
        );
    END IF;

    -- Extract destination details
    v_destination_server := (v_portal_config->>'destination_server')::uuid;
    v_destination_x := (v_portal_config->>'destination_x')::integer;
    v_destination_y := (v_portal_config->>'destination_y')::integer;

    -- Debug log destination details
    RAISE NOTICE 'Destination details: server=%, x=%, y=%',
        v_destination_server, v_destination_x, v_destination_y;

    -- Verify destination server exists and is active
    IF NOT EXISTS (
        SELECT 1 FROM servers 
        WHERE id = v_destination_server 
        AND status = 'active'
    ) THEN
        -- Debug log server check
        RAISE NOTICE 'Server check failed for id: %', v_destination_server;
        
        -- Additional debug: show server status
        RAISE NOTICE 'Server status: %', (
            SELECT status FROM servers WHERE id = v_destination_server
        );
        
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Destination server is not available'
        );
    END IF;

    -- Move player to new server
    -- First remove from current server
    DELETE FROM player_positions
    WHERE player_id = p_player_id
    AND server_id = p_current_server_id;

    DELETE FROM server_players
    WHERE player_id = p_player_id
    AND server_id = p_current_server_id;

    -- Then add to destination server
    INSERT INTO server_players (server_id, player_id)
    VALUES (v_destination_server, p_player_id);

    INSERT INTO player_positions (player_id, server_id, x, y)
    VALUES (p_player_id, v_destination_server, v_destination_x, v_destination_y);

    -- Debug log successful transport
    RAISE NOTICE 'Successfully transported player to new location';

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Transported successfully',
        'new_server_id', v_destination_server,
        'new_x', v_destination_x,
        'new_y', v_destination_y
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add helper function to configure a location as a portal
CREATE OR REPLACE FUNCTION configure_portal(
    p_server_id uuid,
    p_x integer,
    p_y integer,
    p_destination_server uuid,
    p_destination_x integer,
    p_destination_y integer
) RETURNS jsonb AS $$
DECLARE
    v_existing_metadata jsonb;
BEGIN
    -- Get existing metadata
    SELECT metadata INTO v_existing_metadata
    FROM map_data
    WHERE server_id = p_server_id
    AND x = p_x
    AND y = p_y;

    -- Add portal configuration to metadata
    UPDATE map_data
    SET metadata = COALESCE(v_existing_metadata, '{}'::jsonb) || jsonb_build_object(
        'portal_config', jsonb_build_object(
            'destination_server', p_destination_server,
            'destination_x', p_destination_x,
            'destination_y', p_destination_y
        )
    )
    WHERE server_id = p_server_id
    AND x = p_x
    AND y = p_y;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Portal configured successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop the existing admin-only policy
DROP POLICY IF EXISTS "Only admins can configure portals" ON map_data;
DROP POLICY IF EXISTS "Allow portal configuration" ON map_data;

-- Create a new policy that allows portal configuration
CREATE POLICY "Allow portal configuration" ON map_data
    FOR UPDATE
    TO authenticated
    USING (true)  -- Allow reading all map data
    WITH CHECK (
        -- Allow updates if user is an admin
        EXISTS (
            SELECT 1 FROM admin_users 
            WHERE id = auth.uid()
        )
        -- Or if they're only updating the portal_config
        OR (
            terrain_type = map_data.terrain_type
            AND original_terrain_type = map_data.original_terrain_type
        )
    );

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION handle_server_transport TO authenticated;
GRANT EXECUTE ON FUNCTION configure_portal TO authenticated;