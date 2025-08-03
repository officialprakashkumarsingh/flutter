-- ==========================================
-- AHAMAI SIMPLE NO-RECURSION SETUP
-- ==========================================
-- This script provides a simple, recursion-free setup
-- More permissive policies but prevents infinite recursion
-- Perfect for collaboration apps where authenticated users need access

-- (Optional) STEP 1: SAFE CLEANUP (commented out by default)
/*
DELETE FROM auth.users CASCADE;
DROP TABLE IF EXISTS public.room_messages CASCADE;
DROP TABLE IF EXISTS public.room_members CASCADE;
DROP TABLE IF EXISTS public.collaboration_rooms CASCADE;
DROP TABLE IF EXISTS public.chat_conversations CASCADE;
DROP TABLE IF EXISTS public.characters CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.handle_user_update();
DROP FUNCTION IF EXISTS public.update_room_activity();
*/

-- ==========================================
-- STEP 2: CREATE CORE TABLES (SAFE)
-- ==========================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.characters (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    character_type TEXT NOT NULL,
    appearance_description TEXT,
    personality_traits TEXT[],
    special_abilities TEXT[],
    background_story TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.chat_conversations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    character_id UUID REFERENCES public.characters(id) ON DELETE CASCADE,
    title TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==========================================
-- STEP 3: CREATE COLLABORATION TABLES (SAFE)
-- ==========================================

CREATE TABLE IF NOT EXISTS public.collaboration_rooms (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    invite_code TEXT UNIQUE NOT NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT true,
    max_members INTEGER DEFAULT 50,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.room_members (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    room_id UUID REFERENCES public.collaboration_rooms(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'member',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(room_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.room_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    room_id UUID REFERENCES public.collaboration_rooms(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    message_type TEXT DEFAULT 'text',
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==========================================
-- STEP 4: ENABLE ROW LEVEL SECURITY (SAFE)
-- ==========================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collaboration_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_messages ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- STEP 5: CREATE SIMPLE, NON-RECURSIVE POLICIES
-- ==========================================

-- Profiles policies
DO $$ BEGIN DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles; EXCEPTION WHEN others THEN END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles; EXCEPTION WHEN others THEN END $$;

CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR ALL USING (auth.uid() = id);

-- Characters policies  
DO $$ BEGIN DROP POLICY IF EXISTS "Users can manage own characters" ON public.characters; EXCEPTION WHEN others THEN END $$;

CREATE POLICY "Users can manage own characters" ON public.characters
    FOR ALL USING (auth.uid() = user_id);

-- Chat conversations policies
DO $$ BEGIN DROP POLICY IF EXISTS "Users can manage own conversations" ON public.chat_conversations; EXCEPTION WHEN others THEN END $$;

CREATE POLICY "Users can manage own conversations" ON public.chat_conversations
    FOR ALL USING (auth.uid() = user_id);

-- Collaboration rooms policies - SIMPLE & SAFE
DO $$ BEGIN DROP POLICY IF EXISTS "Authenticated users can view all rooms" ON public.collaboration_rooms; EXCEPTION WHEN others THEN END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can create rooms" ON public.collaboration_rooms; EXCEPTION WHEN others THEN END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Room creators can update rooms" ON public.collaboration_rooms; EXCEPTION WHEN others THEN END $$;

-- Allow all authenticated users to see all rooms (they join via invite codes)
CREATE POLICY "Authenticated users can view all rooms" ON public.collaboration_rooms
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can create rooms" ON public.collaboration_rooms
    FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Room creators can update rooms" ON public.collaboration_rooms
    FOR UPDATE USING (auth.uid() = created_by);

-- Room members policies - SIMPLE & SAFE  
DO $$ BEGIN DROP POLICY IF EXISTS "Users can manage own memberships" ON public.room_members; EXCEPTION WHEN others THEN END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Authenticated users can view memberships" ON public.room_members; EXCEPTION WHEN others THEN END $$;

CREATE POLICY "Users can manage own memberships" ON public.room_members
    FOR ALL USING (auth.uid() = user_id);

-- Allow viewing all memberships for authenticated users (needed for room lists)
CREATE POLICY "Authenticated users can view memberships" ON public.room_members
    FOR SELECT USING (auth.role() = 'authenticated');

-- Room messages policies - SIMPLE & SAFE
DO $$ BEGIN DROP POLICY IF EXISTS "Users can view messages" ON public.room_messages; EXCEPTION WHEN others THEN END $$;
DO $$ BEGIN DROP POLICY IF EXISTS "Users can send messages" ON public.room_messages; EXCEPTION WHEN others THEN END $$;

-- Allow authenticated users to see all messages (membership checked by app)
CREATE POLICY "Users can view messages" ON public.room_messages
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can send messages" ON public.room_messages
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ==========================================
-- STEP 6: CREATE FUNCTIONS (SAFE)
-- ==========================================

-- Function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, created_at, updated_at)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
        NOW(),
        NOW()
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle user profile updates
CREATE OR REPLACE FUNCTION public.handle_user_update()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update room activity
CREATE OR REPLACE FUNCTION public.update_room_activity()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.collaboration_rooms
    SET updated_at = NOW()
    WHERE id = NEW.room_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- STEP 7: CREATE TRIGGERS (SAFE)
-- ==========================================

-- User creation trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Profile update trigger
DROP TRIGGER IF EXISTS on_profile_updated ON public.profiles;
CREATE TRIGGER on_profile_updated
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_user_update();

-- Room activity triggers
DROP TRIGGER IF EXISTS on_room_message_created ON public.room_messages;
CREATE TRIGGER on_room_message_created
    AFTER INSERT ON public.room_messages
    FOR EACH ROW EXECUTE FUNCTION public.update_room_activity();

-- ==========================================
-- STEP 8: CREATE INDEXES (SAFE)
-- ==========================================

DROP INDEX IF EXISTS idx_characters_user_id;
CREATE INDEX idx_characters_user_id ON public.characters(user_id);

DROP INDEX IF EXISTS idx_chat_conversations_user_id;
CREATE INDEX idx_chat_conversations_user_id ON public.chat_conversations(user_id);

DROP INDEX IF EXISTS idx_collaboration_rooms_created_by;
CREATE INDEX idx_collaboration_rooms_created_by ON public.collaboration_rooms(created_by);

DROP INDEX IF EXISTS idx_collaboration_rooms_invite_code;
CREATE INDEX idx_collaboration_rooms_invite_code ON public.collaboration_rooms(invite_code);

DROP INDEX IF EXISTS idx_room_members_room_id;
CREATE INDEX idx_room_members_room_id ON public.room_members(room_id);

DROP INDEX IF EXISTS idx_room_members_user_id;
CREATE INDEX idx_room_members_user_id ON public.room_members(user_id);

DROP INDEX IF EXISTS idx_room_messages_room_id;
CREATE INDEX idx_room_messages_room_id ON public.room_messages(room_id);

-- ==========================================
-- STEP 9: GRANT PERMISSIONS (SAFE)
-- ==========================================

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.profiles TO authenticated;
GRANT SELECT ON public.profiles TO anon;
GRANT ALL ON public.characters TO authenticated;
GRANT ALL ON public.chat_conversations TO authenticated;
GRANT ALL ON public.collaboration_rooms TO authenticated;
GRANT ALL ON public.room_members TO authenticated;
GRANT ALL ON public.room_messages TO authenticated;

-- ==========================================
-- STEP 10: ENABLE REALTIME (SAFE)
-- ==========================================

-- Remove any existing realtime subscriptions safely
DO $$ 
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime DROP TABLE public.direct_chats;
    EXCEPTION WHEN others THEN
        NULL;
    END;
    
    BEGIN
        ALTER PUBLICATION supabase_realtime DROP TABLE public.direct_messages;
    EXCEPTION WHEN others THEN
        NULL;
    END;
END $$;

-- Add collaboration tables to realtime (safely)
DO $$ 
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.collaboration_rooms;
    EXCEPTION WHEN others THEN
        NULL;
    END;
    
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.room_members;
    EXCEPTION WHEN others THEN
        NULL;
    END;
    
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.room_messages;
    EXCEPTION WHEN others THEN
        NULL;
    END;
END $$;

-- ==========================================
-- SETUP COMPLETE!
-- ==========================================

/*
✅ SIMPLE SETUP COMPLETE - NO RECURSION ISSUES!

🔧 Features Enabled:
- ✅ User profiles with automatic creation
- ✅ Character management system
- ✅ AI chat conversations
- ✅ Collaboration rooms (create/join via invite codes)
- ✅ Room membership management
- ✅ Real-time room messaging
- ✅ Proper indexing for performance
- ✅ Safe, non-recursive RLS policies

🛡️ Security Model:
- ✅ Authenticated users can view all rooms (join via invite codes)
- ✅ Users can only manage their own data (profiles, characters, messages)
- ✅ Room creators control their rooms
- ✅ Simple permissions prevent infinite recursion

🚀 Ready to use with AhamAI Flutter app!
*/