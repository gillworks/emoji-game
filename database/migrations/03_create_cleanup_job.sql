-- Function to clean up inactive servers
CREATE OR REPLACE FUNCTION cleanup_inactive_servers()
RETURNS void AS $$
BEGIN
  -- Mark servers inactive if no activity for 1 hour
  UPDATE servers 
  SET status = 'inactive'
  WHERE last_active < NOW() - INTERVAL '1 hour'
  AND status = 'active';
  
  -- Delete map data for inactive servers
  DELETE FROM map_data
  WHERE server_id IN (
    SELECT id FROM servers WHERE status = 'inactive'
  );
  
  -- Delete inactive servers with no players
  DELETE FROM servers
  WHERE status = 'inactive'
  AND current_players = 0;
END;
$$ LANGUAGE plpgsql; 