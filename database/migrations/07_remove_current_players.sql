-- Remove current_players column from servers table
ALTER TABLE servers DROP COLUMN current_players;

-- Add new indexes for server_players
CREATE INDEX IF NOT EXISTS idx_server_players_server ON server_players(server_id);
CREATE INDEX IF NOT EXISTS idx_server_players_combined ON server_players(server_id, player_id);

-- Update increment_server_players function to use server_players count
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
$$ LANGUAGE plpgsql;

-- Simplify decrement_server_players to just update timestamp
CREATE OR REPLACE FUNCTION decrement_server_players(server_id UUID)
RETURNS void AS $$
BEGIN
    -- Just update the last_active timestamp
    UPDATE servers 
    SET last_active = NOW()
    WHERE id = server_id;
END;
$$ LANGUAGE plpgsql;

-- Update cleanup_inactive_servers to use server_players count
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
$$ LANGUAGE plpgsql; 