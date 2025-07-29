# Local LLM Setup Guide

This app now supports connecting to locally running AI models instead of relying on remote APIs. This gives you complete privacy and control over your AI conversations.

## Supported Local LLM Servers

The app supports several popular local LLM server options:

### 1. Ollama
- **Default Port**: 11434
- **Endpoint**: `http://localhost:11434`
- **Setup**: Download from https://ollama.ai/
- **Models**: Run `ollama pull llama2` or any other model

### 2. LM Studio
- **Default Port**: 1234
- **Endpoint**: `http://localhost:1234`
- **Setup**: Download from https://lmstudio.ai/
- **Features**: Easy GUI for model management

### 3. Text Generation WebUI (Oobabooga)
- **Default Port**: 5000
- **Endpoint**: `http://localhost:5000`
- **Setup**: Follow instructions at https://github.com/oobabooga/text-generation-webui
- **Features**: Advanced configuration options

### 4. KoboldCpp
- **Default Port**: 5001
- **Endpoint**: `http://localhost:5001`
- **Setup**: Download from https://github.com/LostRuins/koboldcpp
- **Features**: Lightweight C++ implementation

### 5. Custom Endpoints
- **Port**: Configurable
- **Endpoint**: Any OpenAI-compatible API
- **Setup**: Add custom endpoints through the app

## How to Use

1. **Install a Local LLM Server**
   - Choose one of the supported options above
   - Follow their installation instructions
   - Start the server with your preferred model

2. **Connect in the App**
   - Tap the computer icon in the top right
   - Or go to Menu → Local LLMs
   - The app will automatically scan for available servers
   - Tap refresh to rescan if needed

3. **Start Chatting**
   - Select an available LLM server
   - Choose a model from the dropdown
   - Start chatting with your local AI!

## Features

### Privacy First
- All conversations stay on your device
- No data sent to external servers
- Complete offline functionality

### Multiple Model Support
- Switch between different models easily
- Support for various model formats
- Real-time model availability detection

### Seamless Integration
- Same chat interface as cloud models
- External tools still work
- Markdown and code formatting support

### Performance
- Streaming responses for real-time chat
- Optimized for local network communication
- Efficient resource usage

## Troubleshooting

### LLM Server Not Detected
1. Make sure the server is running
2. Check the correct port is being used
3. Verify firewall settings
4. Try the refresh button in the app

### No Models Available
1. Ensure models are downloaded in your LLM server
2. Check server configuration
3. Restart the LLM server
4. Verify API compatibility

### Connection Errors
1. Check server logs for errors
2. Verify endpoint URL is correct
3. Test with curl: `curl http://localhost:11434/api/tags`
4. Try a different port

### Performance Issues
1. Close other resource-intensive apps
2. Use smaller models for faster responses
3. Check available RAM and CPU
4. Consider GPU acceleration if available

## Custom Endpoints

To add a custom local LLM endpoint:

1. Tap the "+" button in Local LLMs
2. Enter a name for your server
3. Enter the full endpoint URL
4. The app will test connectivity
5. Select and start chatting

The endpoint should be OpenAI-compatible with these routes:
- `/v1/models` - List available models
- `/v1/chat/completions` - Chat completion with streaming

## Benefits Over Cloud APIs

- **Privacy**: Your data never leaves your device
- **Cost**: No API fees or usage limits
- **Speed**: No network latency for responses
- **Reliability**: Works offline, no service outages
- **Customization**: Use specialized or fine-tuned models
- **Control**: Full control over model behavior and parameters

## Requirements

- Local LLM server running on your network
- Sufficient RAM (varies by model size)
- Compatible model formats
- Network connectivity to your local server

Enjoy private, local AI conversations with complete control over your data!