-- Drop existing policies
DROP POLICY IF EXISTS "Players can update their own position" ON player_positions;
DROP POLICY IF EXISTS "Player positions are visible to all" ON player_positions;

-- Create new, more specific policies
CREATE POLICY "Players can insert their own position"
    ON player_positions FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = player_id);

CREATE POLICY "Players can update their own position"
    ON player_positions FOR UPDATE
    TO authenticated
    USING (auth.uid() = player_id)
    WITH CHECK (auth.uid() = player_id);

CREATE POLICY "Players can delete their own position"
    ON player_positions FOR DELETE
    TO authenticated
    USING (auth.uid() = player_id);

CREATE POLICY "All players can view positions"
    ON player_positions FOR SELECT
    TO authenticated
    USING (true); 