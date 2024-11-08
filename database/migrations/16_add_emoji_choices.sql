-- Create emoji_choices table
CREATE TABLE emoji_choices (
    id SERIAL PRIMARY KEY,
    emoji TEXT NOT NULL,
    name TEXT NOT NULL,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Add RLS policies
ALTER TABLE emoji_choices ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to view emoji choices
CREATE POLICY "Authenticated users can view emoji choices" ON emoji_choices
    FOR SELECT TO authenticated
    USING (true);

-- Insert default emoji choices
INSERT INTO emoji_choices (emoji, name) VALUES
    ('🐻', 'Bear'),
    ('🐸', 'Frog'),
    ('🐵', 'Monkey'),
    ('🐨', 'Koala'),
    ('🐷', 'Pig'); 