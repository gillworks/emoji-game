-- Add resource spawning configuration
INSERT INTO game_configs (key, value) VALUES
(
    'resource_spawning',
    jsonb_build_object(
        'enabled', true,
        'interval_minutes', 5,
        'spawn_chance', 0.1
    )
);

-- Update the periodic spawning function to check config
CREATE OR REPLACE FUNCTION spawn_resources_periodically(
    p_server_id uuid,
    p_chance float DEFAULT 0.1
) RETURNS void AS $$
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

-- Update the cron job to use the configured interval
SELECT cron.unschedule('spawn-resources');

SELECT cron.schedule(
    'spawn-resources',
    (SELECT format('*/%s * * * *', (value->>'interval_minutes')::int) 
     FROM game_configs 
     WHERE key = 'resource_spawning'),
    $$
    SELECT spawn_resources_periodically(id)
    FROM servers 
    WHERE status = 'active'
    $$
); 