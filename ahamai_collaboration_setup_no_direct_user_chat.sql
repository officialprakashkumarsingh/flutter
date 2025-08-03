-- ==========================================
-- AHAMAI COMPLETE SETUP WITH COLLABORATION (NO USER-TO-USER DIRECT CHAT)
-- ==========================================
-- This script will DELETE ALL EXISTING DATA and create a fresh setup with collaboration
-- but WITHOUT user-to-user direct messaging (keeps AI chat functionality)
-- Run this complete script in your Supabase SQL Editor

-- ==========================================
-- STEP 1: COMPLETE CLEANUP (DELETE EVERYTHING)
-- ==========================================

-- Drop all existing policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own characters" ON public.characters;
DROP POLICY IF EXISTS "Users can insert own characters" ON public.characters;
DROP POLICY IF EXISTS "Users can update own characters" ON public.characters;
DROP POLICY IF EXISTS "Users can delete own characters" ON public.characters;
DROP POLICY IF EXISTS "Users can view own conversations" ON public.chat_conversations;
DROP POLICY IF EXISTS "Users can insert own conversations" ON public.chat_conversations;
DROP POLICY IF EXISTS "Users can update own conversations" ON public.chat_conversations;
DROP POLICY IF EXISTS "Users can delete own conversations" ON public.chat_conversations;

-- Drop collaboration policies
DROP POLICY IF EXISTS "Users can view accessible rooms" ON public.collaboration_rooms;
DROP POLICY IF EXISTS "Users can insert rooms" ON public.collaboration_rooms;
DROP POLICY IF EXISTS "Users can update own rooms" ON public.collaboration_rooms;
DROP POLICY IF EXISTS "Users can delete own rooms" ON public.collaboration_rooms;
DROP POLICY IF EXISTS "Room members can view membership" ON public.room_members;
DROP POLICY IF EXISTS "Room admins can manage members" ON public.room_members;
DROP POLICY IF EXISTS "Users can join rooms" ON public.room_members;
DROP POLICY IF EXISTS "Room members can view messages" ON public.room_messages;
DROP POLICY IF EXISTS "Room members can insert messages" ON public.room_messages;

-- Drop USER-TO-USER direct chat policies (if they exist)
DROP POLICY IF EXISTS "Users can view their own chats" ON public.direct_chats;
DROP POLICY IF EXISTS "Users can create chats they participate in" ON public.direct_chats;
DROP POLICY IF EXISTS "Users can update their own chats" ON public.direct_chats;
DROP POLICY IF EXISTS "Users can view messages in their chats" ON public.direct_messages;
DROP POLICY IF EXISTS "Users can send messages in their chats" ON public.direct_messages;
DROP POLICY IF EXISTS "Users can update their own messages" ON public.direct_messages;

-- Drop all triggers and functions
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
DROP TRIGGER IF EXISTS update_room_last_activity ON public.room_messages;
DROP TRIGGER IF EXISTS update_chat_on_message ON public.direct_messages;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.handle_user_update();
DROP FUNCTION IF EXISTS public.update_room_activity();
DROP FUNCTION IF EXISTS public.update_chat_timestamp();
DROP FUNCTION IF EXISTS public.get_or_create_direct_chat(UUID, UUID);

-- Drop all indexes
DROP INDEX IF EXISTS idx_characters_user_id;
DROP INDEX IF EXISTS idx_characters_is_built_in;
DROP INDEX IF EXISTS idx_characters_is_favorite;
DROP INDEX IF EXISTS idx_chat_conversations_user_id;
DROP INDEX IF EXISTS idx_chat_conversations_is_pinned;
DROP INDEX IF EXISTS idx_chat_conversations_updated_at;
DROP INDEX IF EXISTS idx_chat_conversations_pinned_at;
DROP INDEX IF EXISTS uniq_characters_user_name;
DROP INDEX IF EXISTS idx_collaboration_rooms_invite_code;
DROP INDEX IF EXISTS idx_collaboration_rooms_created_by;
DROP INDEX IF EXISTS idx_collaboration_rooms_is_active;
DROP INDEX IF EXISTS idx_room_members_room_id;
DROP INDEX IF EXISTS idx_room_members_user_id;
DROP INDEX IF EXISTS idx_room_messages_room_id;
DROP INDEX IF EXISTS idx_room_messages_created_at;
DROP INDEX IF EXISTS idx_room_messages_user_id;
-- Drop USER-TO-USER direct chat indexes (if they exist)
DROP INDEX IF EXISTS idx_direct_chats_participants;
DROP INDEX IF EXISTS idx_direct_chats_updated_at;
DROP INDEX IF EXISTS idx_direct_messages_chat_id;
DROP INDEX IF EXISTS idx_direct_messages_sender;

-- Drop USER-TO-USER direct chat tables (but keep AI chat tables)
DROP TABLE IF EXISTS public.direct_messages CASCADE;
DROP TABLE IF EXISTS public.direct_chats CASCADE;

-- Drop collaboration tables
DROP TABLE IF EXISTS public.room_messages CASCADE;
DROP TABLE IF EXISTS public.room_members CASCADE;
DROP TABLE IF EXISTS public.collaboration_rooms CASCADE;

-- Keep AI chat functionality - DO NOT DROP these tables:
-- public.chat_conversations (AI chat history)
-- public.characters (AI characters)  
-- public.profiles (user profiles)

-- NOTE: We are NOT deleting auth users to preserve existing accounts
-- If you need a completely fresh start, uncomment the line below:
-- DELETE FROM auth.users;

-- ==========================================
-- STEP 2: CREATE MAIN APP TABLES (SAFE MODE)
-- ==========================================

-- Create profiles table for user data (only if not exists)
-- This will safely create the table only if it doesn't already exist
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create characters table (for AI characters, only if not exists)
CREATE TABLE IF NOT EXISTS public.characters (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    system_prompt TEXT NOT NULL,
    avatar_url TEXT,
    custom_tag TEXT,
    background_color INTEGER DEFAULT 4294967295,
    is_built_in BOOLEAN DEFAULT FALSE,
    is_favorite BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE(user_id, name) -- Prevent duplicate character names per user
);

-- Create chat conversations table with pin functionality (for AI chat history, only if not exists)
CREATE TABLE IF NOT EXISTS public.chat_conversations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT DEFAULT 'New Chat',
    messages JSONB NOT NULL DEFAULT '[]',
    conversation_memory JSONB NOT NULL DEFAULT '[]',
    is_pinned BOOLEAN DEFAULT FALSE,
    pinned_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ==========================================
-- STEP 3: CREATE COLLABORATION TABLES
-- ==========================================

-- Create collaboration rooms table (only if not exists)
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

-- Create room members table (only if not exists)
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

-- Create room messages table (only if not exists)
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
-- STEP 4: ENABLE ROW LEVEL SECURITY
-- ==========================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collaboration_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_messages ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- STEP 5: CREATE USER POLICIES
-- ==========================================

-- Profiles policies
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Characters policies (for AI characters)
CREATE POLICY "Users can view own characters" ON public.characters
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own characters" ON public.characters
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own characters" ON public.characters
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own characters" ON public.characters
    FOR DELETE USING (auth.uid() = user_id);

-- Chat conversations policies (for AI chat history)
CREATE POLICY "Users can view own conversations" ON public.chat_conversations
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own conversations" ON public.chat_conversations
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own conversations" ON public.chat_conversations
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own conversations" ON public.chat_conversations
    FOR DELETE USING (auth.uid() = user_id);

-- ==========================================
-- STEP 6: CREATE COLLABORATION POLICIES
-- ==========================================

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
-- STEP 7: CREATE TRIGGERS AND FUNCTIONS
-- ==========================================

-- Create function to handle user creation
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

-- Create trigger to automatically create profile when user signs up
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create function to handle profile updates
CREATE OR REPLACE FUNCTION public.handle_user_update()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.profiles
    SET 
        email = NEW.email,
        full_name = COALESCE(NEW.raw_user_meta_data->>'full_name', OLD.raw_user_meta_data->>'full_name', NEW.email),
        updated_at = NOW()
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to update profile when user data changes
CREATE TRIGGER on_auth_user_updated
    AFTER UPDATE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_user_update();

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
-- STEP 8: CREATE INDEXES FOR PERFORMANCE
-- ==========================================

-- Main app indexes (AI chat functionality)
CREATE INDEX idx_characters_user_id ON public.characters(user_id);
CREATE INDEX idx_characters_is_built_in ON public.characters(is_built_in);
CREATE INDEX idx_characters_is_favorite ON public.characters(is_favorite);
CREATE INDEX idx_chat_conversations_user_id ON public.chat_conversations(user_id);
CREATE INDEX idx_chat_conversations_is_pinned ON public.chat_conversations(is_pinned);
CREATE INDEX idx_chat_conversations_updated_at ON public.chat_conversations(updated_at);
CREATE INDEX idx_chat_conversations_pinned_at ON public.chat_conversations(pinned_at);

-- Collaboration indexes
CREATE INDEX idx_collaboration_rooms_invite_code ON public.collaboration_rooms(invite_code);
CREATE INDEX idx_collaboration_rooms_created_by ON public.collaboration_rooms(created_by);
CREATE INDEX idx_collaboration_rooms_is_active ON public.collaboration_rooms(is_active);
CREATE INDEX idx_room_members_room_id ON public.room_members(room_id);
CREATE INDEX idx_room_members_user_id ON public.room_members(user_id);
CREATE INDEX idx_room_messages_room_id ON public.room_messages(room_id);
CREATE INDEX idx_room_messages_created_at ON public.room_messages(created_at);
CREATE INDEX idx_room_messages_user_id ON public.room_messages(user_id);

-- Prevent duplicate character names
CREATE UNIQUE INDEX uniq_characters_user_name
    ON public.characters (user_id, LOWER(name));

-- ==========================================
-- STEP 9: ENABLE REALTIME
-- ==========================================

-- Enable realtime for collaboration tables only (not for user-to-user direct chats)
-- Safe addition - only add if not already in publication
DO $$ 
BEGIN
    -- Try to add collaboration_rooms to publication
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.collaboration_rooms;
    EXCEPTION WHEN others THEN
        -- Table already in publication, continue
    END;
    
    -- Try to add room_members to publication
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.room_members;
    EXCEPTION WHEN others THEN
        -- Table already in publication, continue
    END;
    
    -- Try to add room_messages to publication
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.room_messages;
    EXCEPTION WHEN others THEN
        -- Table already in publication, continue
    END;
END $$;

-- ==========================================
-- STEP 10: GRANT PERMISSIONS
-- ==========================================

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.profiles TO authenticated;
GRANT SELECT ON public.profiles TO anon;
GRANT ALL ON public.characters TO authenticated;
GRANT ALL ON public.chat_conversations TO authenticated;
GRANT ALL ON public.collaboration_rooms TO authenticated;
GRANT ALL ON public.room_members TO authenticated;
GRANT ALL ON public.room_messages TO authenticated;

-- ==========================================
-- STEP 11: CLEANUP USER-TO-USER DIRECT CHAT REMNANTS
-- ==========================================

-- Remove any realtime subscriptions for user-to-user direct chat tables (if they exist)
DO $$ 
BEGIN
    -- Try to drop direct_chats from publication if it exists
    BEGIN
        ALTER PUBLICATION supabase_realtime DROP TABLE public.direct_chats;
    EXCEPTION WHEN others THEN
        -- Table doesn't exist in publication, continue
    END;
    
    -- Try to drop direct_messages from publication if it exists
    BEGIN
        ALTER PUBLICATION supabase_realtime DROP TABLE public.direct_messages;
    EXCEPTION WHEN others THEN
        -- Table doesn't exist in publication, continue
    END;
END $$;

-- ==========================================
-- SETUP COMPLETE!
-- ==========================================

SELECT 'AhamAI Complete Setup with Collaboration (No User-to-User Direct Chat) Completed Successfully!' as status,
       'All existing data has been deleted and fresh setup created' as warning,
       'AI Chat Features: Characters, Chat History, Pinning - ALL PRESERVED' as ai_features,
       'Collaboration Features: Rooms, Real-time messaging, Member management - AVAILABLE' as collab_features,
       'User-to-User Direct Chat: REMOVED (only collaboration rooms for user communication)' as removed_features,
       'Realtime enabled on: collaboration_rooms, room_members, room_messages' as realtime_info;