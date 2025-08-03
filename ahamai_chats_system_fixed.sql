-- AhamAI Chats System - Direct User Messaging (FIXED VERSION)
-- This adds direct user-to-user messaging functionality

-- Create direct_chats table for 1-on-1 conversations
CREATE TABLE IF NOT EXISTS direct_chats (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    participant_1 UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    participant_2 UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_message_id UUID,
    
    -- Ensure participants are different and maintain order
    CONSTRAINT different_participants CHECK (participant_1 != participant_2),
    CONSTRAINT ordered_participants CHECK (participant_1 < participant_2),
    
    -- Unique constraint to prevent duplicate chats
    UNIQUE(participant_1, participant_2)
);

-- Create direct_messages table for chat messages
CREATE TABLE IF NOT EXISTS direct_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    chat_id UUID REFERENCES direct_chats(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'system')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_read BOOLEAN DEFAULT FALSE
);

-- Add foreign key constraint for last_message_id after both tables are created
ALTER TABLE direct_chats 
ADD CONSTRAINT fk_last_message 
FOREIGN KEY (last_message_id) REFERENCES direct_messages(id) ON DELETE SET NULL;

-- Enable RLS on new tables
ALTER TABLE direct_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE direct_messages ENABLE ROW LEVEL SECURITY;

-- Policies for direct_chats
CREATE POLICY "Users can view their own chats" ON direct_chats
    FOR SELECT USING (
        auth.uid() = participant_1 OR auth.uid() = participant_2
    );

CREATE POLICY "Users can create chats they participate in" ON direct_chats
    FOR INSERT WITH CHECK (
        auth.uid() = participant_1 OR auth.uid() = participant_2
    );

CREATE POLICY "Users can update their own chats" ON direct_chats
    FOR UPDATE USING (
        auth.uid() = participant_1 OR auth.uid() = participant_2
    );

-- Policies for direct_messages
CREATE POLICY "Users can view messages in their chats" ON direct_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM direct_chats 
            WHERE direct_chats.id = direct_messages.chat_id 
            AND (direct_chats.participant_1 = auth.uid() OR direct_chats.participant_2 = auth.uid())
        )
    );

CREATE POLICY "Users can send messages in their chats" ON direct_messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id AND
        EXISTS (
            SELECT 1 FROM direct_chats 
            WHERE direct_chats.id = direct_messages.chat_id 
            AND (direct_chats.participant_1 = auth.uid() OR direct_chats.participant_2 = auth.uid())
        )
    );

CREATE POLICY "Users can update their own messages" ON direct_messages
    FOR UPDATE USING (sender_id = auth.uid());

-- Function to update chat's updated_at timestamp
CREATE OR REPLACE FUNCTION update_chat_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE direct_chats 
    SET updated_at = NOW(), last_message_id = NEW.id
    WHERE id = NEW.chat_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update chat timestamp when new message is sent
CREATE TRIGGER update_chat_on_message
    AFTER INSERT ON direct_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_chat_timestamp();

-- Enable realtime for new tables
ALTER PUBLICATION supabase_realtime ADD TABLE direct_chats;
ALTER PUBLICATION supabase_realtime ADD TABLE direct_messages;

-- Grant permissions to authenticated users
GRANT ALL ON direct_chats TO authenticated;
GRANT ALL ON direct_messages TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Create indexes for better performance (SEPARATE FROM TABLE DEFINITIONS)
CREATE INDEX IF NOT EXISTS idx_direct_chats_participants ON direct_chats(participant_1, participant_2);
CREATE INDEX IF NOT EXISTS idx_direct_chats_updated_at ON direct_chats(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_direct_messages_chat_id ON direct_messages(chat_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_direct_messages_sender ON direct_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_direct_messages_created_at ON direct_messages(created_at);

-- Function to find or create a direct chat between two users
CREATE OR REPLACE FUNCTION get_or_create_direct_chat(user1_id UUID, user2_id UUID)
RETURNS UUID AS $$
DECLARE
    chat_id UUID;
    participant1 UUID;
    participant2 UUID;
BEGIN
    -- Ensure consistent ordering
    IF user1_id < user2_id THEN
        participant1 := user1_id;
        participant2 := user2_id;
    ELSE
        participant1 := user2_id;
        participant2 := user1_id;
    END IF;
    
    -- Try to find existing chat
    SELECT id INTO chat_id
    FROM direct_chats
    WHERE participant_1 = participant1 AND participant_2 = participant2;
    
    -- If not found, create new chat
    IF chat_id IS NULL THEN
        INSERT INTO direct_chats (participant_1, participant_2)
        VALUES (participant1, participant2)
        RETURNING id INTO chat_id;
    END IF;
    
    RETURN chat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Verification queries
SELECT 'Direct chats system installed successfully!' as status;
SELECT COUNT(*) as direct_chats_count FROM direct_chats;
SELECT COUNT(*) as direct_messages_count FROM direct_messages;