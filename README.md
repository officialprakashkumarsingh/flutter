# AhamAI - Intelligent AI Assistant

A modern Flutter application with Supabase authentication and admin panel for AI model management.

## 🚀 Quick Setup

### Supabase Database Setup

Run this **single SQL command** in your Supabase SQL Editor to set up the complete database:

```sql
-- Enable Row Level Security
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

-- Create profiles table for user data
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable RLS on profiles table
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create policy for users to see their own profile
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

-- Create policy for users to update their own profile
CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- Create policy for users to insert their own profile
CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Create function to handle user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data->>'full_name'
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
        full_name = NEW.raw_user_meta_data->>'full_name',
        updated_at = NOW()
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to update profile when user data changes
CREATE TRIGGER on_auth_user_updated
    AFTER UPDATE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_user_update();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.profiles TO authenticated;
GRANT SELECT ON public.profiles TO anon;
```

## 📱 Features

### ✅ **Authentication System**
- **Supabase Auth**: Secure email/password authentication
- **Auto Profile Creation**: Automatic user profile creation on signup
- **Password Reset**: Email-based password recovery
- **Session Management**: Secure session handling with auto-expiry

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
├── Admin Panel (Local + Supabase)
├── Chat Interface
├── File Processing
└── API Management
```

### Data Flow

```
User Input → Admin Settings → Cloudflare Workers → AI APIs → Response
```

## 📊 Database Schema

### Profiles Table
- `id` (UUID, Primary Key, References auth.users)
- `email` (Text, Unique)
- `full_name` (Text, Optional)
- `avatar_url` (Text, Optional)
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

### For Admins
1. **Access Admin Panel**: Use admin password to access controls
2. **Configure APIs**: Set up different AI models and providers
3. **Test Connections**: Verify API settings before applying
4. **Monitor Usage**: Track which models are being used

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
