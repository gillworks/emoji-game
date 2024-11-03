-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS increment_server_players(UUID);
DROP FUNCTION IF EXISTS decrement_server_players(UUID);

-- Recreate functions with proper schema
CREATE OR REPLACE FUNCTION public.increment_server_players(server_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE public.servers 
  SET current_players = current_players + 1,
      last_active = NOW()
  WHERE id = server_id;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.decrement_server_players(server_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE public.servers 
  SET current_players = GREATEST(current_players - 1, 0),
      last_active = NOW()
  WHERE id = server_id;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.increment_server_players(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decrement_server_players(UUID) TO authenticated; 