-- Enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Function to periodically spawn resources
CREATE OR REPLACE FUNCTION spawn_resources_periodically(
    p_server_id uuid,
    p_chance float DEFAULT 0.1
) RETURNS void AS $$
DECLARE
    v_x integer;
    v_y integer;
BEGIN
    -- Get all empty tiles (no current resource)
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
        -- Try spawn with given chance
        IF random() < p_chance THEN
            PERFORM try_spawn_resource(p_server_id, v_x, v_y);
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add a cron job to spawn resources every 5 minutes
SELECT cron.schedule(
    'spawn-resources',
    '*/5 * * * *',
    $$
    SELECT spawn_resources_periodically(id, 0.1)
    FROM servers 
    WHERE status = 'active'
    $$
); 