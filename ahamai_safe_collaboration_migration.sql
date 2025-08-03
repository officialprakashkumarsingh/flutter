-- ==========================================
-- AHAMAI SAFE COLLABORATION MIGRATION
-- ==========================================
-- This script PRESERVES all existing data and only ADDS collaboration features
-- Safe to run - will not delete any chat history, users, or characters!

-- ==========================================
-- STEP 1: CREATE NEW COLLABORATION TABLES
-- ==========================================

-- Create collaboration rooms table (if not exists)
CREATE TABLE IF NOT EXISTS public.collaboration_rooms (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    invite_code TEXT UNIQUE NOT NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    max_members INTEGER DEFAULT 10,
    is_active BOOLEAN DEFAULT TRUE,
    settings JSONB DEFAULT '{"allowFileSharing": true, "allowVoiceNotes": false}',
    last_activity TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create room members table (if not exists)
CREATE TABLE IF NOT EXISTS public.room_members (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    room_id UUID REFERENCES public.collaboration_rooms(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    role TEXT DEFAULT 'member' CHECK (role IN ('admin', 'member')),
    joined_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(room_id, user_id) -- Prevent duplicate memberships
);

-- Create room messages table (if not exists)
CREATE TABLE IF NOT EXISTS public.room_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    room_id UUID REFERENCES public.collaboration_rooms(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    content TEXT NOT NULL,
    message_type TEXT DEFAULT 'user' CHECK (message_type IN ('user', 'ai', 'system')),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ==========================================
-- STEP 2: ENABLE ROW LEVEL SECURITY (ONLY FOR NEW TABLES)
-- ==========================================

-- Enable RLS on collaboration tables
ALTER TABLE public.collaboration_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_messages ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- STEP 3: CREATE COLLABORATION POLICIES
-- ==========================================

-- Drop existing collaboration policies if they exist (safe cleanup)
DROP POLICY IF EXISTS "Users can view accessible rooms" ON public.collaboration_rooms;
DROP POLICY IF EXISTS "Users can insert rooms" ON public.collaboration_rooms;
DROP POLICY IF EXISTS "Users can update own rooms" ON public.collaboration_rooms;
DROP POLICY IF EXISTS "Users can delete own rooms" ON public.collaboration_rooms;
DROP POLICY IF EXISTS "Room members can view membership" ON public.room_members;
DROP POLICY IF EXISTS "Room admins can manage members" ON public.room_members;
DROP POLICY IF EXISTS "Users can join rooms" ON public.room_members;
DROP POLICY IF EXISTS "Room members can view messages" ON public.room_messages;
DROP POLICY IF EXISTS "Room members can insert messages" ON public.room_messages;

-- Collaboration rooms policies
CREATE POLICY "Users can view accessible rooms" ON public.collaboration_rooms
    FOR SELECT USING (
        auth.uid() = created_by OR 
        EXISTS (
            SELECT 1 FROM public.room_members 
            WHERE room_id = collaboration_rooms.id 
            AND user_id = auth.uid() 
            AND is_active = true
        )
    );

CREATE POLICY "Users can insert rooms" ON public.collaboration_rooms
    FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Users can update own rooms" ON public.collaboration_rooms
    FOR UPDATE USING (
        auth.uid() = created_by OR 
        EXISTS (
            SELECT 1 FROM public.room_members 
            WHERE room_id = collaboration_rooms.id 
            AND user_id = auth.uid() 
            AND role = 'admin'
            AND is_active = true
        )
    );

CREATE POLICY "Users can delete own rooms" ON public.collaboration_rooms
    FOR DELETE USING (auth.uid() = created_by);

-- Room members policies
CREATE POLICY "Room members can view membership" ON public.room_members
    FOR SELECT USING (
        auth.uid() = user_id OR 
        EXISTS (
            SELECT 1 FROM public.room_members rm 
            WHERE rm.room_id = room_members.room_id 
            AND rm.user_id = auth.uid() 
            AND rm.is_active = true
        )
    );

CREATE POLICY "Room admins can manage members" ON public.room_members
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.collaboration_rooms cr 
            WHERE cr.id = room_members.room_id 
            AND cr.created_by = auth.uid()
        ) OR
        EXISTS (
            SELECT 1 FROM public.room_members rm 
            WHERE rm.room_id = room_members.room_id 
            AND rm.user_id = auth.uid() 
            AND rm.role = 'admin'
            AND rm.is_active = true
        )
    );

CREATE POLICY "Users can join rooms" ON public.room_members
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Room messages policies
CREATE POLICY "Room members can view messages" ON public.room_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.room_members 
            WHERE room_id = room_messages.room_id 
            AND user_id = auth.uid() 
            AND is_active = true
        )
    );

CREATE POLICY "Room members can insert messages" ON public.room_messages
    FOR INSERT WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM public.room_members 
            WHERE room_id = room_messages.room_id 
            AND user_id = auth.uid() 
            AND is_active = true
        )
    );

-- ==========================================
-- STEP 4: CREATE OR REPLACE FUNCTIONS AND TRIGGERS
-- ==========================================

-- Drop existing collaboration functions if they exist
DROP FUNCTION IF EXISTS public.update_room_activity();
DROP TRIGGER IF EXISTS update_room_last_activity ON public.room_messages;

-- Create function to update room activity
CREATE OR REPLACE FUNCTION public.update_room_activity()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.collaboration_rooms 
    SET last_activity = NOW(), updated_at = NOW()
    WHERE id = NEW.room_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to update room activity when message is sent
CREATE TRIGGER update_room_last_activity
    AFTER INSERT ON public.room_messages
    FOR EACH ROW EXECUTE FUNCTION public.update_room_activity();

-- ==========================================
-- STEP 5: CREATE INDEXES FOR PERFORMANCE
-- ==========================================

-- Drop existing collaboration indexes if they exist (safe)
DROP INDEX IF EXISTS idx_collaboration_rooms_invite_code;
DROP INDEX IF EXISTS idx_collaboration_rooms_created_by;
DROP INDEX IF EXISTS idx_collaboration_rooms_is_active;
DROP INDEX IF EXISTS idx_room_members_room_id;
DROP INDEX IF EXISTS idx_room_members_user_id;
DROP INDEX IF EXISTS idx_room_messages_room_id;
DROP INDEX IF EXISTS idx_room_messages_created_at;
DROP INDEX IF EXISTS idx_room_messages_user_id;

-- Create collaboration indexes
CREATE INDEX idx_collaboration_rooms_invite_code ON public.collaboration_rooms(invite_code);
CREATE INDEX idx_collaboration_rooms_created_by ON public.collaboration_rooms(created_by);
CREATE INDEX idx_collaboration_rooms_is_active ON public.collaboration_rooms(is_active);
CREATE INDEX idx_room_members_room_id ON public.room_members(room_id);
CREATE INDEX idx_room_members_user_id ON public.room_members(user_id);
CREATE INDEX idx_room_messages_room_id ON public.room_messages(room_id);
CREATE INDEX idx_room_messages_created_at ON public.room_messages(created_at);
CREATE INDEX idx_room_messages_user_id ON public.room_messages(user_id);

-- ==========================================
-- STEP 6: ENABLE REALTIME FOR NEW TABLES
-- ==========================================

-- Enable realtime for collaboration tables (safe - won't affect existing)
DO $$
BEGIN
    -- Add tables to realtime publication if not already added
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'collaboration_rooms'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.collaboration_rooms;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'room_members'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.room_members;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'room_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.room_messages;
    END IF;
END $$;

-- ==========================================
-- STEP 7: GRANT PERMISSIONS
-- ==========================================

-- Grant necessary permissions for collaboration tables
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.collaboration_rooms TO authenticated;
GRANT ALL ON public.room_members TO authenticated;
GRANT ALL ON public.room_messages TO authenticated;

-- ==========================================
-- STEP 8: VERIFY EXISTING TABLES (OPTIONAL CHECK)
-- ==========================================

-- Show existing table status (this is just informational)
DO $$
DECLARE
    existing_tables TEXT;
BEGIN
    SELECT string_agg(tablename, ', ')
    INTO existing_tables
    FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename IN ('profiles', 'characters', 'chat_conversations');
    
    RAISE NOTICE 'Existing preserved tables: %', COALESCE(existing_tables, 'None found');
END $$;

-- ==========================================
-- STEP 9: INSERT SAMPLE COLLABORATION ROOM (OPTIONAL)
-- ==========================================

-- Uncomment this section if you want a sample room created
-- You'll need to replace the UUID with an actual user ID from your auth.users table

/*
-- Insert a sample collaboration room (replace with real user ID)
DO $$
DECLARE
    sample_user_id UUID;
BEGIN
    -- Get the first user ID (you might want to use a specific user)
    SELECT id INTO sample_user_id FROM auth.users LIMIT 1;
    
    IF sample_user_id IS NOT NULL THEN
        INSERT INTO public.collaboration_rooms (name, description, invite_code, created_by)
        VALUES (
            'Welcome Room',
            'A sample collaboration room to get you started!',
            'HELLO1',
            sample_user_id
        ) ON CONFLICT (invite_code) DO NOTHING;
        
        -- Add creator as admin
        INSERT INTO public.room_members (room_id, user_id, role)
        SELECT cr.id, sample_user_id, 'admin'
        FROM public.collaboration_rooms cr
        WHERE cr.invite_code = 'HELLO1'
        ON CONFLICT (room_id, user_id) DO NOTHING;
        
        -- Add welcome message
        INSERT INTO public.room_messages (room_id, user_id, user_name, content, message_type)
        SELECT cr.id, NULL, 'System', 'Welcome to AhamAI Collaboration! 🎉', 'system'
        FROM public.collaboration_rooms cr
        WHERE cr.invite_code = 'HELLO1';
    END IF;
END $$;
*/

-- ==========================================
-- MIGRATION COMPLETE! ✅
-- ==========================================

SELECT 
    'AhamAI Collaboration Migration Completed Successfully! 🚀' as status,
    'All existing data preserved - No chat history lost!' as preservation_status,
    'New collaboration features added: Rooms, Real-time messaging, Member management' as new_features,
    'Realtime enabled on: collaboration_rooms, room_members, room_messages' as realtime_info,
    'Ready to use - No data loss!' as safety_confirmation;