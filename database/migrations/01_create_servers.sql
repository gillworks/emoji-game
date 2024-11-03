-- Create servers table
CREATE TABLE servers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_active TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    max_players INTEGER DEFAULT 100,
    current_players INTEGER DEFAULT 0
);

-- Create map_data table to store the actual map for each server
CREATE TABLE map_data (
    server_id UUID REFERENCES servers(id),
    x INTEGER,
    y INTEGER,
    terrain_type TEXT NOT NULL,
    PRIMARY KEY (server_id, x, y)
);

-- Create server_players junction table
CREATE TABLE server_players (
    server_id UUID REFERENCES servers(id),
    player_id UUID REFERENCES players(id),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (server_id, player_id)
);

-- Add RLS policies
ALTER TABLE servers ENABLE ROW LEVEL SECURITY;
ALTER TABLE map_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE server_players ENABLE ROW LEVEL SECURITY;

-- Servers policies
CREATE POLICY "Servers are viewable by all authenticated users"
    ON servers FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated users can create servers"
    ON servers FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Map data policies
CREATE POLICY "Map data is viewable by all authenticated users"
    ON map_data FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Map data can be inserted by authenticated users"
    ON map_data FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Server players policies
CREATE POLICY "Server players is viewable by all authenticated users"
    ON server_players FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Players can join servers"
    ON server_players FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = player_id);

CREATE POLICY "Players can leave servers"
    ON server_players FOR DELETE
    TO authenticated
    USING (auth.uid() = player_id); 