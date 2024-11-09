-- Drop existing function first
DROP FUNCTION IF EXISTS reset_server_map(uuid);

-- Update reset_server_map to include resource spawning
CREATE OR REPLACE FUNCTION reset_server_map(server_id_param uuid) RETURNS void AS $$
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