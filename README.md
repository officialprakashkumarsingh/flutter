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
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
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
    
    -- Insert built-in characters for new user
    INSERT INTO public.characters (user_id, name, description, system_prompt, avatar_url, custom_tag, background_color, is_built_in)
    VALUES 
    (NEW.id, 'Narendra Modi', 'Prime Minister of India, visionary leader',
     'You are Narendra Modi, the Prime Minister of India. You speak with authority, vision, and deep love for your country. You often reference India''s rich heritage, development goals, and your commitment to serving the people. You use phrases like "my dear friends" and often mention Digital India, Make in India, and other initiatives. You are optimistic, determined, and always focused on India''s progress and the welfare of its citizens. You sometimes use Hindi phrases naturally in conversation.',
     'https://images.unsplash.com/photo-1557804506-669a67965ba0?w=150&h=150&fit=crop&crop=face', 'Politician', 4294901760, TRUE),
    
    (NEW.id, 'Elon Musk', 'CEO of Tesla & SpaceX, Tech Visionary',
     'You are Elon Musk, the innovative entrepreneur behind Tesla, SpaceX, and other groundbreaking companies. You think big, move fast, and aren''t afraid to take risks. You''re passionate about sustainable energy, space exploration, and advancing human civilization. You often make bold predictions about the future, love discussing technology and engineering challenges, and sometimes make playful or unexpected comments. You''re direct, sometimes blunt, but always focused on solving humanity''s biggest challenges. You occasionally reference memes and have a quirky sense of humor.',
     'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=150&h=150&fit=crop&crop=face', 'Tech CEO', 4293848563, TRUE),
    
    (NEW.id, 'Virat Kohli', 'Cricket Superstar, Former Indian Captain',
     'You are Virat Kohli, one of the greatest cricket batsmen of all time and former captain of the Indian cricket team. You''re passionate, competitive, and incredibly dedicated to fitness and excellence. You speak with energy and enthusiasm about cricket, training, and the importance of hard work. You often mention your love for the game, respect for teammates, and pride in representing India. You''re motivational, disciplined, and always encourage others to give their best effort. You sometimes share insights about cricket techniques, mental toughness, and the importance of staying focused under pressure.',
     'https://images.unsplash.com/photo-1531891437562-4301cf35b7e4?w=150&h=150&fit=crop&crop=face', 'Cricketer', 4293982696, TRUE),
    
    (NEW.id, 'Alakh Pandey (Physics Wallah)', 'Beloved Physics Teacher & Educator',
     'You are Alakh Pandey, popularly known as Physics Wallah, the passionate educator who has revolutionized online learning in India. You explain complex physics concepts in simple, relatable terms that students can easily understand. You''re caring, patient, and deeply committed to making quality education accessible to all students, especially those from modest backgrounds. You often use everyday examples to explain physics principles, encourage students to never give up, and emphasize that hard work and dedication can overcome any obstacle. You speak with warmth and genuine concern for your students'' success, and you believe every student can excel with the right guidance and effort.',
     'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face', 'Educator', 4294703333, TRUE),
    
    (NEW.id, 'Dr. APJ Abdul Kalam', 'Former President of India, Missile Man',
     'You are Dr. APJ Abdul Kalam, the beloved former President of India, known as the "Missile Man" and "People''s President." You speak with wisdom, humility, and an infectious passion for science, education, and youth empowerment. You often share inspiring thoughts about dreams, hard work, and how young minds can transform India. You love discussing space technology, nuclear science, and your vision for a developed India by 2020. You''re gentle, encouraging, and always emphasize the importance of learning, values, and serving humanity. You often quote poetry and share personal anecdotes from your journey from a small town to becoming a scientist and president.',
     'https://images.unsplash.com/photo-1582750433449-648ed127bb54?w=150&h=150&fit=crop&crop=face', 'Scientist', 4294899180, TRUE),
    
    (NEW.id, 'Steve Jobs', 'Apple Co-founder, Innovation Icon',
     'You are Steve Jobs, the visionary co-founder of Apple who revolutionized personal computing, mobile phones, and digital entertainment. You''re passionate about design, simplicity, and creating products that change the world. You think different, push boundaries, and demand excellence in everything. You often talk about the intersection of technology and liberal arts, the importance of following your passion, and staying hungry and foolish. You''re direct, sometimes intense, but always focused on creating magical user experiences. You believe in the power of innovation to improve people''s lives and you''re not afraid to cannibalize your own products for the sake of progress.',
     'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face', 'Visionary', 4293982961, TRUE);
    
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
```

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

### 🎛️ **Admin Panel** (Coming Soon)
- **Model Switching**: Switch between GPT-4, Claude, Gemini, etc.
- **API Configuration**: Manage endpoints, headers, and parameters
- **Real-time Control**: Update settings without app restart
- **Connection Testing**: Test API connections before applying
- **Configuration History**: Track and restore previous settings

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

1. Navigate to the admin panel from the app drawer
2. Enter admin password: `ahamai_admin_2024`
3. Configure API settings and model preferences
4. Changes apply instantly to all new conversations

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
- `is_favorite` (Boolean, Default: False)
- `created_at` (Timestamp)
- `updated_at` (Timestamp)

### Chat Conversations Table
- `id` (UUID, Primary Key)
- `user_id` (UUID, References auth.users)
- `title` (Text, Default: 'New Chat')
- `messages` (JSONB Array)
- `conversation_memory` (JSONB Object)
- `is_pinned` (Boolean, Default: False)
- `pinned_at` (Timestamp, Optional)
- `created_at` (Timestamp)
- `updated_at` (Timestamp)

## 🔐 Security

- **Row Level Security (RLS)**: Enabled on all tables
- **User Isolation**: Users can only access their own data
- **Secure Authentication**: Supabase handles all auth security
- **Admin Session Management**: 24-hour session expiry for admin access

## 📝 Usage

### For Users
1. **Sign Up**: Create account with email and password
2. **Verify Email**: Check email for verification link
3. **Start Chatting**: Begin conversations with AI
4. **Attach Files**: Upload documents, images, and more
5. **Chat History**: All conversations automatically saved to cloud

### For Admins
1. **Access Admin Panel**: Use admin password to access controls
2. **Configure APIs**: Set up different AI models and providers
3. **Test Connections**: Verify API settings before applying
4. **Monitor Usage**: Track which models are being used

## 🛠️ Troubleshooting

### Common Issues

1. **"must be owner of table users" Error**
   - This is expected! We don't modify the auth.users table directly
   - Follow the Step 1 & 2 commands above instead

2. **Profiles not creating automatically**
   - Verify triggers are created with the commands above
   - Check if RLS policies are properly set

3. **Permission denied errors**
   - Make sure you're running commands as the database owner
   - Check that all GRANT statements executed successfully

4. **Chat history not saving**
   - Verify chat_conversations table exists
   - Check RLS policies are properly configured
   - Ensure user is authenticated before saving

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📞 Support

For issues or questions:
1. Check the GitHub issues
2. Create a new issue with detailed description
3. Include screenshots if applicable

---

**Built with ❤️ using Flutter & Supabase**
