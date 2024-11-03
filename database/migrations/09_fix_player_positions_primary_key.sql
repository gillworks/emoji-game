-- First drop the existing primary key
ALTER TABLE player_positions 
DROP CONSTRAINT player_positions_pkey;

-- Create new composite primary key with both player_id and server_id
ALTER TABLE player_positions
ADD PRIMARY KEY (player_id, server_id);

-- Make sure we have the proper indexes
DROP INDEX IF EXISTS idx_player_positions_server;
CREATE INDEX idx_player_positions_player_server ON player_positions(player_id, server_id);
CREATE INDEX idx_player_positions_server ON player_positions(server_id); 