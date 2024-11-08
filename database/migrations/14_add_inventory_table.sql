-- Create inventory table
CREATE TABLE player_inventory (
    player_id UUID REFERENCES players(id),
    slot INTEGER CHECK (slot >= 1 AND slot <= 10),
    item_type TEXT NOT NULL,
    quantity INTEGER DEFAULT 1 CHECK (quantity > 0),
    PRIMARY KEY (player_id, slot)
);

-- Enable RLS
ALTER TABLE player_inventory ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Players can view their own inventory"
    ON player_inventory FOR SELECT
    TO authenticated
    USING (auth.uid() = player_id);

CREATE POLICY "Players can insert into their own inventory"
    ON player_inventory FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = player_id);

CREATE POLICY "Players can update their own inventory"
    ON player_inventory FOR UPDATE
    TO authenticated
    USING (auth.uid() = player_id)
    WITH CHECK (auth.uid() = player_id);

CREATE POLICY "Players can delete from their own inventory"
    ON player_inventory FOR DELETE
    TO authenticated
    USING (auth.uid() = player_id);

-- Insert default axe for all existing players
INSERT INTO player_inventory (player_id, slot, item_type, quantity)
SELECT id, 1, 'AXE', 1
FROM players
ON CONFLICT (player_id, slot) DO NOTHING; 