-- Initial database schema for Emoji Adventure

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Players table
CREATE TABLE players (
    id UUID PRIMARY KEY,
    username TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Player positions table
CREATE TABLE player_positions (
    player_id UUID REFERENCES players(id),
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (player_id)
);

-- Terrain types table
CREATE TABLE terrain_types (
    id TEXT PRIMARY KEY,
    emoji TEXT NOT NULL,
    encounter TEXT NOT NULL
);

-- Game configs table
CREATE TABLE game_configs (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Admin users table
CREATE TABLE admin_users (
    id UUID PRIMARY KEY REFERENCES players(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE terrain_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Players policies
CREATE POLICY "Users can insert their own player record"
    ON players FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own player record"
    ON players FOR UPDATE
    TO authenticated
    USING (auth.uid() = id);

CREATE POLICY "Users can view all player records"
    ON players FOR SELECT
    TO authenticated
    USING (true);

-- Player positions policies
CREATE POLICY "Players can update their own position"
    ON player_positions FOR ALL
    TO authenticated
    USING (auth.uid() = player_id);

CREATE POLICY "Player positions are visible to all"
    ON player_positions FOR SELECT
    TO authenticated
    USING (true);

-- Game configs policies
CREATE POLICY "Configs are readable by all authenticated users"
    ON game_configs FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Only admins can modify configs"
    ON game_configs 
    FOR ALL
    TO authenticated
    USING (auth.uid() IN (SELECT id FROM admin_users));

-- Initial data
INSERT INTO terrain_types (id, emoji, encounter) VALUES
    ('FOREST', '🌳', '🐺'),
    ('MOUNTAIN', '🏔️', '🐆'),
    ('PLAIN', '🌱', '🦁'),
    ('OCEAN', '🌊', '🦈');

INSERT INTO game_configs (key, value) VALUES
    ('encounter_rates', '{"FOREST": 0.3, "MOUNTAIN": 0.4, "PLAIN": 0.2, "OCEAN": 0.3}'::jsonb);

-- Enable realtime for relevant tables
ALTER PUBLICATION supabase_realtime ADD TABLE player_positions; 