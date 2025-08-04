# AhamAI - Perplexity AI Clone

A modern Android application built with Jetpack Compose that replicates the Perplexity AI user interface and experience. AhamAI features a beautiful Material 3 design system with support for dynamic theming.

## Features

- 🎨 **Material 3 Design** - Modern UI with dynamic color theming
- 💬 **Chat Interface** - Interactive AI chat with message bubbles
- 🔍 **Smart Search** - Search bar with attachment support
- 🎯 **Focus Modes** - Different AI response modes (Academic, Writing, etc.)
- 📚 **Thread Library** - Save and manage conversation threads
- 🌟 **Discover Section** - Trending topics and popular questions
- 👤 **User Profile** - Settings and preferences management
- 🌓 **Dark Mode** - Full dark theme support
- 📱 **Responsive Design** - Optimized for all screen sizes

## Tech Stack

- **Language**: Kotlin
- **UI Framework**: Jetpack Compose
- **Design System**: Material 3 (Material You)
- **Architecture**: MVVM with StateFlow
- **Navigation**: Navigation Compose
- **Async**: Kotlin Coroutines
- **Image Loading**: Coil

## Project Structure

```
AhamAI/
├── app/
│   ├── src/main/java/com/aham/ai/
│   │   ├── data/          # Data models
│   │   ├── navigation/    # Navigation setup
│   │   ├── ui/           
│   │   │   ├── components/# Reusable UI components
│   │   │   ├── screens/   # App screens
│   │   │   └── theme/     # Material 3 theme
│   │   ├── viewmodel/     # ViewModels
│   │   └── MainActivity.kt
│   └── src/main/res/      # Resources
└── gradle/                # Gradle configuration
```

## Setup Instructions

1. **Prerequisites**
   - Android Studio Hedgehog (2023.1.1) or newer
   - Android SDK 34
   - JDK 11 or higher

2. **Clone and Open**
   ```bash
   git clone <repository-url>
   cd AhamAI
   ```

3. **Configure SDK Path**
   - Open `local.properties`
   - Set your Android SDK path:
     ```
     sdk.dir=/path/to/your/Android/Sdk
     ```

4. **Build and Run**
   - Open the project in Android Studio
   - Sync Gradle files
   - Run on emulator or physical device (API 24+)

## Key Components

### Screens
- **ChatScreen** - Main chat interface with AI responses
- **LibraryScreen** - Saved threads and collections
- **DiscoverScreen** - Trending topics and suggestions
- **ProfileScreen** - User settings and preferences

### UI Components
- **SearchBar** - Material 3 search with attachments
- **MessageCard** - Chat message display with sources
- **SourceCard** - Citation cards with favicons
- **AhamAIBottomBar** - Navigation bar with icons

### Data Models
- **Message** - Chat message with metadata
- **Thread** - Conversation thread
- **Source** - Web source citations
- **FocusMode** - AI response modes

## Features Implementation

- ✅ Complete UI implementation
- ✅ Navigation between screens
- ✅ State management with ViewModel
- ✅ Material 3 theming
- ✅ Responsive layouts
- ✅ Mock data and responses
- ⏳ Real API integration (future)
- ⏳ Data persistence (future)
- ⏳ User authentication (future)

## Package Name
`com.aham.ai`

## Version
1.0.0

## License
This is a demo project for educational purposes.

---

Built with ❤️ using Jetpack Compose and Material 3