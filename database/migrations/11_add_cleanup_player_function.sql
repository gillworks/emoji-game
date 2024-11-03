-- Create a function to handle player cleanup
CREATE OR REPLACE FUNCTION cleanup_player(player_id UUID, server_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;

-- Create an API endpoint for the cleanup function
CREATE OR REPLACE FUNCTION handle_cleanup_request()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Get the player_id from the current session
  PERFORM cleanup_player(auth.uid(), server_id);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION cleanup_player TO authenticated;
GRANT EXECUTE ON FUNCTION handle_cleanup_request TO authenticated; 