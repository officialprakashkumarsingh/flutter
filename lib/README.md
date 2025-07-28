# AhamAI

AhamAI is a modern Flutter-based AI chatbot application that provides access to multiple Claude AI models through a custom Cloudflare Workers API.

## Features

- Multiple Claude AI models support:
  - claude-3-5-sonnet
  - claude-3-7-sonnet  
  - claude-sonnet-4
  - claude-3-5-sonnet-ashlynn (custom endpoint)
- **External Tools Integration**: AI has access to external tools and can use them on demand
  - Screenshot tool for capturing any webpage visually
  - AI model fetching and switching for optimal performance
  - Web search for current information
- Character-based conversations with customizable AI personas
- Image generation capabilities
- User authentication and profile management
- Responsive and minimalistic UI design
- Real-time chat with streaming support
- **Tool-Aware AI**: The AI understands its external capabilities and informs users about them

## External Tools System

AhamAI features a sophisticated external tools system that gives the AI access to various capabilities beyond just conversation:

### Available Tools

1. **Screenshot Tool** (`external_tools_service.dart`)
   - Captures screenshots of any webpage
   - Uses WordPress mshots API for reliable screenshots
   - Configurable dimensions and options
   - AI can visually understand websites and help with web content

2. **AI Models Management**
   - Dynamically fetches available AI models from the API
   - Allows switching between models when performance is suboptimal
   - AI can recommend model changes based on user satisfaction
   - Automatic model validation and error handling

3. **Web Search**
   - Searches Wikipedia and other sources for current information
   - Provides up-to-date information beyond the AI's training data
   - AI can gather recent news and information on any topic

### How It Works

- **AI Awareness**: The AI receives system prompts that inform it about available external tools
- **Natural Usage**: Users can request tool functionality naturally in conversation
- **Transparent Operation**: Clear indicators show when tools are being used
- **Error Handling**: Robust error handling with user-friendly feedback
- **Tool Integration**: Results are seamlessly integrated into AI responses

### Example Interactions

```
User: "Can you take a screenshot of google.com?"
AI: "I can help you with that! I have access to a screenshot tool that can capture any webpage visually. Let me take a screenshot of google.com for you..."

User: "This AI model isn't working well"
AI: "I understand your concern. I have the ability to fetch available AI models and switch to a different one that might work better for your needs. Let me check what other models are available..."
```

## API Configuration

### Cloudflare Workers API

The app uses a Cloudflare Workers API deployed at:
```
https://ahamai-api.officialprakashkrsingh.workers.dev
```

#### API Endpoints

- `GET /` or `GET /v1/models` - List all available models
- `GET /v1/chat/models` - List chat models only
- `GET /v1/images/models` - List image generation models
- `POST /v1/chat/completions` - Chat completions (OpenAI compatible)
- `POST /v1/images/generations` - Image generation

#### Authentication

All API requests require Bearer token authentication:
```
Authorization: Bearer ahamaibyprakash25
```

#### Supported Models

**Chat Models:**
- `claude-3-5-sonnet` → `anthropic/claude-3-5-sonnet`
- `claude-3-7-sonnet` → `anthropic/claude-3-7-sonnet`
- `claude-sonnet-4` → `anthropic/claude-sonnet-4`
- `claude-3-5-sonnet-ashlynn` → `ashlynn/claude-3-5-sonnet`

**Image Models:**
- `flux` - High quality image generation
- `turbo` - Fast image generation

#### Model Routes

- Claude models: `http://V1.s1.sdk.li/v1/chat/completions`
- Ashlynn model: `https://ai.ashlynn.workers.dev/ask`
- Image models: `https://image.pollinations.ai/prompt/`

### API Usage Examples

#### Chat Completion
```bash
curl -X POST https://ahamai-api.officialprakashkrsingh.workers.dev/v1/chat/completions \
  -H "Authorization: Bearer ahamaibyprakash25" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet-ashlynn",
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ],
    "stream": false
  }'
```

#### List Models
```bash
curl -X GET https://ahamai-api.officialprakashkrsingh.workers.dev/v1/models \
  -H "Authorization: Bearer ahamaibyprakash25"
```

## Pubspec.yaml Dependencies

```yaml
name: aham_ai
description: AI Chatbot with multiple Claude models

dependencies:
  flutter:
    sdk: flutter
  google_fonts: ^6.1.0
  http: ^1.1.0
  shared_preferences: ^2.2.2
  path_provider: ^2.1.1
  image_picker: ^1.0.4
  file_picker: ^6.1.1
  url_launcher: ^6.2.1
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
```

## Android Manifest Configuration

Add these permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Internet permission for API calls -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <!-- File access permissions -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    
    <!-- Camera permission for image capture -->
    <uses-permission android:name="android.permission.CAMERA" />
    
    <application
        android:name="${applicationName}"
        android:exported="true"
        android:icon="@mipmap/ic_launcher">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme" />
              
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    
    <!-- Required to query activities that can process text -->
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT" />
            <data android:mimeType="text/plain" />
        </intent>
    </queries>
</manifest>
```

## Workers.js Updates

The latest workers.js includes:
- Fixed CORS headers for cross-origin requests
- Support for all Claude models including claude-3-5-sonnet-ashlynn
- Proper error handling and response formatting
- OpenAI-compatible API responses
- Streaming support for real-time chat

## Deployment

1. **Cloudflare Workers**: Deploy the `workers.js` file to Cloudflare Workers
2. **Flutter App**: Build and deploy to your preferred platform (iOS/Android/Web)
3. **Environment**: Ensure API endpoints are accessible and properly configured

## Troubleshooting

### Model Not Supported Error
If you get "Model 'claude-3-5-sonnet-ashlynn' is not supported" error:
1. Verify the workers.js is properly deployed with latest changes
2. Check the API endpoint is responding correctly
3. Ensure the model mapping exists in `exposedToInternalMap`

### API Connection Issues
1. Verify the API URL in `main_shell.dart`
2. Check authentication token
3. Ensure CORS headers are properly configured in workers.js

### Build Issues
1. Run `flutter clean && flutter pub get`
2. Check all dependencies are properly resolved
3. Verify Android permissions are correctly set

## UI Updates

The app now features:
- Minimalistic design without unnecessary gradients
- Removed background colors from character cards for cleaner look
- Simplified login/signup pages with better UX
- Removed chat icons from character interaction buttons
- Improved responsiveness across different screen sizes