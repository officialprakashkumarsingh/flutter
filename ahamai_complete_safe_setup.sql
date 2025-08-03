-- ==========================================
-- AHAMAI COMPLETE SAFE SETUP - ALL IN ONE
-- ==========================================
-- This script safely sets up the complete AhamAI database
-- Works on: Fresh databases, existing databases, partial setups
-- No errors on existing tables, policies, or functions
-- Run this entire script in your Supabase SQL Editor

-- ==========================================
-- STEP 1: SAFE CLEANUP (OPTIONAL)
-- ==========================================
-- Uncomment the section below ONLY if you want a completely fresh start
-- This will delete ALL data and user accounts

/*
-- WARNING: This will delete ALL user accounts and data
-- Only uncomment if you want to start completely fresh
DELETE FROM auth.users CASCADE;

-- Drop all tables for fresh start
DROP TABLE IF EXISTS public.room_messages CASCADE;
DROP TABLE IF EXISTS public.room_members CASCADE;
DROP TABLE IF EXISTS public.collaboration_rooms CASCADE;
DROP TABLE IF EXISTS public.direct_messages CASCADE;
DROP TABLE IF EXISTS public.direct_chats CASCADE;
DROP TABLE IF EXISTS public.chat_conversations CASCADE;
DROP TABLE IF EXISTS public.characters CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Drop all functions and triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.handle_user_update();
DROP FUNCTION IF EXISTS public.update_room_activity();
DROP FUNCTION IF EXISTS public.update_chat_timestamp();
DROP FUNCTION IF EXISTS public.get_or_create_direct_chat(UUID, UUID);
*/

-- ==========================================
-- STEP 2: CREATE CORE TABLES (SAFE)
-- ==========================================

-- Create profiles table for user data
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create characters table (for AI characters)
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

-- Create chat conversations table with pin functionality (for AI chat history)
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
-- STEP 3: CREATE COLLABORATION TABLES (SAFE)
-- ==========================================

-- Create collaboration rooms table
CREATE TABLE IF NOT EXISTS public.collaboration_rooms (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    invite_code TEXT UNIQUE NOT NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    max_members INTEGER DEFAULT 10,
    is_active BOOLEAN DEFAULT TRUE,
    settings JSONB DEFAULT '{"allowFileSharing": true, "allowVoiceNotes": false}',
    last_activity TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create room members table
CREATE TABLE IF NOT EXISTS public.room_members (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    room_id UUID REFERENCES public.collaboration_rooms(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    role TEXT DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
    joined_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE(room_id, user_id) -- Prevent duplicate memberships
);

-- Create room messages table
CREATE TABLE IF NOT EXISTS public.room_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    room_id UUID REFERENCES public.collaboration_rooms(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    content TEXT NOT NULL,
    message_type TEXT DEFAULT 'user' CHECK (message_type IN ('user', 'ai', 'system')),
    ai_model TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ==========================================
-- STEP 4: ENABLE ROW LEVEL SECURITY (SAFE)
-- ==========================================

-- Enable RLS on all tables (safe operation)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collaboration_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_messages ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- STEP 5: CREATE POLICIES (SAFE)
-- ==========================================

-- Profiles policies
DO $$ 
BEGIN
    -- Drop existing policies if they exist, then create new ones
    DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
    DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
    DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
EXCEPTION WHEN others THEN 
    -- Policies don't exist, continue
END $$;

CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Characters policies
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can view own characters" ON public.characters;
    DROP POLICY IF EXISTS "Users can insert own characters" ON public.characters;
    DROP POLICY IF EXISTS "Users can update own characters" ON public.characters;
    DROP POLICY IF EXISTS "Users can delete own characters" ON public.characters;
EXCEPTION WHEN others THEN 
    -- Policies don't exist, continue
END $$;

CREATE POLICY "Users can view own characters" ON public.characters
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own characters" ON public.characters
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own characters" ON public.characters
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own characters" ON public.characters
    FOR DELETE USING (auth.uid() = user_id);

-- Chat conversations policies
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can view own conversations" ON public.chat_conversations;
    DROP POLICY IF EXISTS "Users can insert own conversations" ON public.chat_conversations;
    DROP POLICY IF EXISTS "Users can update own conversations" ON public.chat_conversations;
    DROP POLICY IF EXISTS "Users can delete own conversations" ON public.chat_conversations;
EXCEPTION WHEN others THEN 
    -- Policies don't exist, continue
END $$;

CREATE POLICY "Users can view own conversations" ON public.chat_conversations
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own conversations" ON public.chat_conversations
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own conversations" ON public.chat_conversations
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own conversations" ON public.chat_conversations
    FOR DELETE USING (auth.uid() = user_id);

-- Collaboration rooms policies
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can view rooms they're members of" ON public.collaboration_rooms;
    DROP POLICY IF EXISTS "Users can create rooms" ON public.collaboration_rooms;
    DROP POLICY IF EXISTS "Room creators can update their rooms" ON public.collaboration_rooms;
    DROP POLICY IF EXISTS "Room creators can delete their rooms" ON public.collaboration_rooms;
EXCEPTION WHEN others THEN 
    -- Policies don't exist, continue
END $$;

CREATE POLICY "Users can view rooms they're members of" ON public.collaboration_rooms
    FOR SELECT USING (
        auth.uid() = created_by OR 
        EXISTS (
            SELECT 1 FROM public.room_members 
            WHERE room_id = id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create rooms" ON public.collaboration_rooms
    FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Room creators can update their rooms" ON public.collaboration_rooms
    FOR UPDATE USING (auth.uid() = created_by);

CREATE POLICY "Room creators can delete their rooms" ON public.collaboration_rooms
    FOR DELETE USING (auth.uid() = created_by);

-- Room members policies
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can view room members" ON public.room_members;
    DROP POLICY IF EXISTS "Users can join rooms" ON public.room_members;
    DROP POLICY IF EXISTS "Users can leave rooms" ON public.room_members;
EXCEPTION WHEN others THEN 
    -- Policies don't exist, continue
END $$;

CREATE POLICY "Users can view room members" ON public.room_members
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.room_members rm
            WHERE rm.room_id = room_id AND rm.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can join rooms" ON public.room_members
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave rooms" ON public.room_members
    FOR DELETE USING (auth.uid() = user_id);

-- Room messages policies
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Room members can view messages" ON public.room_messages;
    DROP POLICY IF EXISTS "Room members can send messages" ON public.room_messages;
EXCEPTION WHEN others THEN 
    -- Policies don't exist, continue
END $$;

CREATE POLICY "Room members can view messages" ON public.room_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.room_members rm
            WHERE rm.room_id = room_messages.room_id AND rm.user_id = auth.uid()
        )
    );

CREATE POLICY "Room members can send messages" ON public.room_messages
    FOR INSERT WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM public.room_members rm
            WHERE rm.room_id = room_messages.room_id AND rm.user_id = auth.uid()
        )
    );

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

-- Function to handle user updates
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

-- Function to update room activity
CREATE OR REPLACE FUNCTION public.update_room_activity()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.collaboration_rooms
    SET 
        last_activity = NOW(),
        updated_at = NOW()
    WHERE id = NEW.room_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- STEP 7: CREATE TRIGGERS (SAFE)
-- ==========================================

-- Drop existing triggers first
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
DROP TRIGGER IF EXISTS on_room_message_created ON public.room_messages;

-- Create triggers
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER on_auth_user_updated
    AFTER UPDATE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_user_update();

CREATE TRIGGER on_room_message_created
    AFTER INSERT ON public.room_messages
    FOR EACH ROW EXECUTE FUNCTION public.update_room_activity();

-- ==========================================
-- STEP 8: CREATE INDEXES (SAFE)
-- ==========================================

-- Drop existing indexes first, then create
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

-- Create performance indexes
CREATE INDEX idx_characters_user_id ON public.characters(user_id);
CREATE INDEX idx_characters_is_built_in ON public.characters(is_built_in);
CREATE INDEX idx_characters_is_favorite ON public.characters(is_favorite);
CREATE INDEX idx_chat_conversations_user_id ON public.chat_conversations(user_id);
CREATE INDEX idx_chat_conversations_is_pinned ON public.chat_conversations(is_pinned);
CREATE INDEX idx_chat_conversations_updated_at ON public.chat_conversations(updated_at);
CREATE INDEX idx_chat_conversations_pinned_at ON public.chat_conversations(pinned_at);
CREATE UNIQUE INDEX uniq_characters_user_name ON public.characters (user_id, LOWER(name));
CREATE INDEX idx_collaboration_rooms_invite_code ON public.collaboration_rooms(invite_code);
CREATE INDEX idx_collaboration_rooms_created_by ON public.collaboration_rooms(created_by);
CREATE INDEX idx_collaboration_rooms_is_active ON public.collaboration_rooms(is_active);
CREATE INDEX idx_room_members_room_id ON public.room_members(room_id);
CREATE INDEX idx_room_members_user_id ON public.room_members(user_id);
CREATE INDEX idx_room_messages_room_id ON public.room_messages(room_id);
CREATE INDEX idx_room_messages_created_at ON public.room_messages(created_at);
CREATE INDEX idx_room_messages_user_id ON public.room_messages(user_id);

-- ==========================================
-- STEP 9: GRANT PERMISSIONS (SAFE)
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
-- STEP 10: ENABLE REALTIME (SAFE)
-- ==========================================

-- Remove any existing realtime subscriptions safely
DO $$ 
BEGIN
    -- Try to drop from publication if they exist
    BEGIN
        ALTER PUBLICATION supabase_realtime DROP TABLE public.direct_chats;
    EXCEPTION WHEN others THEN
        -- Table doesn't exist in publication, continue
    END;
    
    BEGIN
        ALTER PUBLICATION supabase_realtime DROP TABLE public.direct_messages;
    EXCEPTION WHEN others THEN
        -- Table doesn't exist in publication, continue
    END;
END $$;

-- Add collaboration tables to realtime (safely, only if not already added)
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
-- STEP 11: CLEANUP DUPLICATE DATA (SAFE)
-- ==========================================

-- Clean up any duplicate characters (keeps newest)
WITH ranked AS (
  SELECT id,
         ROW_NUMBER() OVER (
             PARTITION BY user_id, LOWER(name)
             ORDER BY created_at DESC
         ) AS rn
  FROM public.characters
)
DELETE FROM public.characters
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

-- ==========================================
-- SETUP COMPLETE!
-- ==========================================
-- 
-- ✅ All tables created safely with IF NOT EXISTS
-- ✅ All policies configured with safe recreate
-- ✅ All functions and triggers set up
-- ✅ All indexes created for performance
-- ✅ Realtime enabled for collaboration
-- ✅ Duplicate data cleaned up
-- ✅ Permissions granted correctly
--
-- Your AhamAI database is now ready!
-- 
-- Features enabled:
-- 🤖 AI Chat with character system
-- 📱 User profiles and authentication  
-- 🤝 Collaboration rooms (No direct user chat)
-- 📊 Real-time updates
-- 🔒 Row Level Security
-- ⚡ Optimized with indexes
--
-- Note: Built-in characters will be created automatically 
-- by the app when users first visit the Characters page.
--