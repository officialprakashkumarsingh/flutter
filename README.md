# AhamAI - Intelligent AI Assistant

A modern Flutter application with Supabase authentication and admin panel for AI model management.

## 🚀 Quick Setup

### Supabase Database Setup

**Step 1: Clean up any existing setup (run this first if you've tried before):**

```sql
-- Clean up existing setup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.handle_user_update();
DROP TABLE IF EXISTS public.characters;
DROP TABLE IF EXISTS public.chat_conversations;
DROP TABLE IF EXISTS public.profiles;
```

**Step 2: Run this complete setup command:**

```sql
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

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;

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

-- Create indexes for better performance
CREATE INDEX idx_characters_user_id ON public.characters(user_id);
CREATE INDEX idx_characters_is_built_in ON public.characters(is_built_in);
CREATE INDEX idx_characters_is_favorite ON public.characters(is_favorite);
CREATE INDEX idx_chat_conversations_user_id ON public.chat_conversations(user_id);
CREATE INDEX idx_chat_conversations_is_pinned ON public.chat_conversations(is_pinned);
CREATE INDEX idx_chat_conversations_updated_at ON public.chat_conversations(updated_at);
CREATE INDEX idx_chat_conversations_pinned_at ON public.chat_conversations(pinned_at);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.profiles TO authenticated;
GRANT SELECT ON public.profiles TO anon;
GRANT ALL ON public.characters TO authenticated;
GRANT ALL ON public.chat_conversations TO authenticated;

```sql
-- Cleanup duplicate character rows (keeps the newest row per (user_id, name))
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

-- Prevent future duplicates
CREATE UNIQUE INDEX IF NOT EXISTS uniq_characters_user_name
    ON public.characters (user_id, LOWER(name));
```

-- Note: Built-in characters will be created automatically by the app when users first visit the Characters page
-- This ensures better error handling and doesn't interfere with user registration

**Step 3: Test the setup (optional verification):**

```sql
-- Verify the setup
SELECT 
    schemaname,
    tablename,
    attname,
    ty.typname AS typename
FROM pg_tables t
JOIN pg_attribute a ON a.attrelid = (
    SELECT oid 
    FROM pg_class 
    WHERE relname = t.tablename 
    AND relnamespace = (
        SELECT oid 
        FROM pg_namespace 
        WHERE nspname = t.schemaname
    )
)
JOIN pg_type ty ON ty.oid = a.atttypid
WHERE t.tablename IN ('profiles', 'chat_conversations') 
AND t.schemaname = 'public'
AND a.attnum > 0
ORDER BY t.tablename, a.attnum;
```

## 📱 Features

### ✅ **Authentication System**
- **Supabase Auth**: Secure email/password authentication
- **Auto Profile Creation**: Automatic user profile creation on signup
- **Password Reset**: Email-based password recovery
- **Session Management**: Secure session handling with auto-expiry

### 💬 **Chat History & Storage**
- **Cloud Storage**: Chat history stored securely in Supabase
- **Real-time Sync**: Messages sync across devices
- **Conversation Memory**: AI context preserved per conversation
- **User Isolation**: Each user's chats are completely private

### 🎛️ **Admin Panel** ✅
- **Dashboard**: Overview statistics and user activity
- **User Management**: View and manage all registered users
- **App Settings**: Configure application-wide settings
- **Real-time Control**: Monitor app usage and performance
- **Secure Access**: Admin-only authentication system

### 🤖 **AI Chat Interface**
- **File Attachments**: Support for various file types (PDF, images, documents)
- **Code Highlighting**: Syntax highlighting for multiple languages
- **Thinking Panels**: Collapsible panels for AI reasoning
- **Message History**: Save and manage chat conversations
- **Character Personas**: Pre-defined AI personalities

### 🎨 **Modern UI/UX**
- **Splash Screen**: Animated robot with India flag
- **Dark/Light Themes**: Adaptive design for all preferences
- **Smooth Animations**: Fluid transitions and micro-interactions
- **Responsive Layout**: Works on all screen sizes

## 🔧 Configuration

### Environment Setup

1. **Flutter Dependencies**: All dependencies are configured in `pubspec.yaml`
2. **Supabase**: Project URL and API key are configured in `main.dart`
3. **Admin Panel**: Default password is `ahamai_admin_2024`

### Admin Panel Access

**To access the admin panel:**

1. **Login with admin credentials on the regular login page:**
   - Email: `officialprakashkrsingh@gmail.com`
   - Password: `admin1234`
2. **Automatic redirect:**
   - Admin users are automatically redirected to the admin panel after login
   - No menu option needed - access is through login credentials only
3. **Features:**
   - Real-time user statistics and dashboard
   - User management and activity tracking  
   - Application settings configuration
   - Secure admin-only access
   - Clean logout back to login page

## 🏗️ Architecture

```
Flutter App
├── Authentication (Supabase)
├── Chat Storage (Supabase Database)
├── Admin Panel (Local + Supabase)
├── Chat Interface
├── File Processing
└── API Management
```

### Data Flow

```
User Input → Admin Settings → Cloudflare Workers → AI APIs → Response → Supabase Storage
```

## 📊 Database Schema

### Profiles Table
- `id` (UUID, Primary Key, References auth.users)
- `email` (Text, Unique)
- `full_name` (Text, Optional)
- `avatar_url` (Text, Optional)
- `created_at` (Timestamp)
- `updated_at` (Timestamp)

### Characters Table
- `id` (UUID, Primary Key)
- `user_id` (UUID, References auth.users)
- `name` (Text, Not Null)
- `description` (Text, Not Null)
- `system_prompt` (Text, Not Null)
- `avatar_url` (Text, Optional)
- `custom_tag` (Text, Optional)
- `background_color` (Integer, Default: 4294967295)
- `is_built_in` (Boolean, Default: False)
- `