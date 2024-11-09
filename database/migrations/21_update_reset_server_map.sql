CREATE OR REPLACE FUNCTION reset_server_map(server_id_param uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Update all tiles back to their original terrain
    UPDATE map_data
    SET terrain_type = original_terrain_type
    WHERE server_id = server_id_param;

    -- Reset all hit counters for this server by creating a new object without the server's keys
    UPDATE item_terrain_actions
    SET current_hits = (
        SELECT jsonb_object_agg(key, value)
        FROM jsonb_each(current_hits)
        WHERE key NOT LIKE server_id_param || '%'
    )
    WHERE current_hits ?| ARRAY(
        SELECT key::text
        FROM jsonb_each(current_hits)
        WHERE key LIKE server_id_param || '%'
    );
END;
$$; 