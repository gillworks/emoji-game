-- Add color column to terrain_types table
ALTER TABLE terrain_types ADD COLUMN color TEXT NOT NULL DEFAULT 'rgba(255, 255, 255, 0.3)';

-- Update existing terrain types with their colors
UPDATE terrain_types SET color = 'rgba(76, 175, 80, 0.3)' WHERE id = 'FOREST';
UPDATE terrain_types SET color = 'rgba(158, 158, 158, 0.3)' WHERE id = 'MOUNTAIN';
UPDATE terrain_types SET color = 'rgba(139, 195, 74, 0.3)' WHERE id = 'PLAIN';
UPDATE terrain_types SET color = 'rgba(33, 150, 243, 0.3)' WHERE id = 'OCEAN';
UPDATE terrain_types SET color = 'rgba(76, 175, 80, 0.3)' WHERE id = 'EMPTY_FOREST'; 