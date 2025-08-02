-- ==========================================
-- AHAMAI CLEAN SETUP (NO ADMIN PANEL)
-- ==========================================
-- This script will DELETE ALL EXISTING DATA and create a fresh setup
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

-- Drop all triggers and functions
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.handle_user_update();

-- Drop all indexes
DROP INDEX IF EXISTS idx_characters_user_id;
DROP INDEX IF EXISTS idx_characters_is_built_in;
DROP INDEX IF EXISTS idx_characters_is_favorite;
DROP INDEX IF EXISTS idx_chat_conversations_user_id;
DROP INDEX IF EXISTS idx_chat_conversations_is_pinned;
DROP INDEX IF EXISTS idx_chat_conversations_updated_at;
DROP INDEX IF EXISTS idx_chat_conversations_pinned_at;
DROP INDEX IF EXISTS uniq_characters_user_name;

-- Drop all main tables
DROP TABLE IF EXISTS public.chat_conversations CASCADE;
DROP TABLE IF EXISTS public.characters CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Delete all auth users (THIS WILL DELETE ALL USER ACCOUNTS)
DELETE FROM auth.users;

-- ==========================================
-- STEP 2: CREATE MAIN APP TABLES
-- ==========================================

-- Create profiles table for user data
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create characters table
CREATE TABLE public.characters (
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

-- Create chat conversations table with pin functionality
CREATE TABLE public.chat_conversations (
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
-- STEP 3: ENABLE ROW LEVEL SECURITY
-- ==========================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- STEP 4: CREATE USER POLICIES
-- ==========================================

-- Profiles policies
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Characters policies
CREATE POLICY "Users can view own characters" ON public.characters
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own characters" ON public.characters
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own characters" ON public.characters
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own characters" ON public.characters
    FOR DELETE USING (auth.uid() = user_id);

-- Chat conversations policies
CREATE POLICY "Users can view own conversations" ON public.chat_conversations
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own conversations" ON public.chat_conversations
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own conversations" ON public.chat_conversations
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own conversations" ON public.chat_conversations
    FOR DELETE USING (auth.uid() = user_id);

-- ==========================================
-- STEP 5: CREATE TRIGGERS AND FUNCTIONS
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

-- ==========================================
-- STEP 6: CREATE INDEXES FOR PERFORMANCE
-- ==========================================

-- Main app indexes
CREATE INDEX idx_characters_user_id ON public.characters(user_id);
CREATE INDEX idx_characters_is_built_in ON public.characters(is_built_in);
CREATE INDEX idx_characters_is_favorite ON public.characters(is_favorite);
CREATE INDEX idx_chat_conversations_user_id ON public.chat_conversations(user_id);
CREATE INDEX idx_chat_conversations_is_pinned ON public.chat_conversations(is_pinned);
CREATE INDEX idx_chat_conversations_updated_at ON public.chat_conversations(updated_at);
CREATE INDEX idx_chat_conversations_pinned_at ON public.chat_conversations(pinned_at);

-- Prevent duplicate character names
CREATE UNIQUE INDEX uniq_characters_user_name
    ON public.characters (user_id, LOWER(name));

-- ==========================================
-- STEP 7: GRANT PERMISSIONS
-- ==========================================

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.profiles TO authenticated;
GRANT SELECT ON public.profiles TO anon;
GRANT ALL ON public.characters TO authenticated;
GRANT ALL ON public.chat_conversations TO authenticated;

-- ==========================================
-- SETUP COMPLETE!
-- ==========================================

SELECT 'AhamAI Clean Setup Completed Successfully!' as status,
       'All existing data has been deleted and fresh setup created' as warning,
       'No admin panel - regular users only' as note;