-- Add server_id to player_positions
ALTER TABLE player_positions 
ADD COLUMN server_id UUID REFERENCES servers(id);

-- Update existing positions with server_id from server_players
UPDATE player_positions pp
SET server_id = sp.server_id
FROM server_players sp
WHERE pp.player_id = sp.player_id;

-- Make server_id NOT NULL
ALTER TABLE player_positions 
ALTER COLUMN server_id SET NOT NULL;

-- Add index for performance
CREATE INDEX idx_player_positions_server 
ON player_positions(server_id); 