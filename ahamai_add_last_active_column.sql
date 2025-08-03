-- Add last_active column to room_members table
-- This fixes the PostgrestException: Could not find the 'last_active' column

-- Add the missing last_active column
ALTER TABLE room_members 
ADD COLUMN IF NOT EXISTS last_active TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Update existing records to have a default last_active value
UPDATE room_members 
SET last_active = joined_at 
WHERE last_active IS NULL;

-- Add an index for better performance on last_active queries
CREATE INDEX IF NOT EXISTS idx_room_members_last_active 
ON room_members (last_active);

-- Create a function to automatically update last_active when members are active
CREATE OR REPLACE FUNCTION update_member_last_active()
RETURNS TRIGGER AS $$
BEGIN
  -- Update last_active whenever a member sends a message
  UPDATE room_members 
  SET last_active = NOW() 
  WHERE room_id = NEW.room_id 
    AND user_id = NEW.user_id 
    AND is_active = true;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update last_active when messages are sent
DROP TRIGGER IF EXISTS trigger_update_member_activity ON room_messages;
CREATE TRIGGER trigger_update_member_activity
  AFTER INSERT ON room_messages
  FOR EACH ROW
  WHEN (NEW.message_type = 'user')
  EXECUTE FUNCTION update_member_last_active();

-- Verification query
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'room_members' 
  AND column_name = 'last_active';

-- Show sample data
SELECT 
  user_name,
  room_id,
  joined_at,
  last_active,
  is_active
FROM room_members 
LIMIT 5;