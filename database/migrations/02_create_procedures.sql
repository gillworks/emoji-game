-- Function to increment server player count
CREATE OR REPLACE FUNCTION increment_server_players(server_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE servers 
  SET current_players = current_players + 1,
      last_active = NOW()
  WHERE id = server_id;
END;
$$ LANGUAGE plpgsql;

-- Function to decrement server player count
CREATE OR REPLACE FUNCTION decrement_server_players(server_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE servers 
  SET current_players = GREATEST(current_players - 1, 0),
      last_active = NOW()
  WHERE id = server_id;
END;
$$ LANGUAGE plpgsql; 