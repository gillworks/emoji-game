-- Add EMPTY_FOREST to terrain_types
INSERT INTO terrain_types (id, emoji, encounter) VALUES
    ('EMPTY_FOREST', '🌱', '🐺');

-- Update any existing game_configs to include EMPTY_FOREST encounter rate
UPDATE game_configs 
SET value = value || jsonb_build_object('EMPTY_FOREST', 0)
WHERE key = 'encounter_rates';

-- Allow EMPTY_FOREST as a valid terrain_type in map_data
ALTER TABLE map_data 
DROP CONSTRAINT IF EXISTS valid_terrain_types;

ALTER TABLE map_data
ADD CONSTRAINT valid_terrain_types 
CHECK (terrain_type IN ('FOREST', 'MOUNTAIN', 'PLAIN', 'OCEAN', 'EMPTY_FOREST')); 