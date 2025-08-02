# Tool Usage Examples for AI Assistant

## Overview
The AI assistant can now execute external tools using JSON format. When users request functionality that requires external tools, the AI should use the proper JSON syntax to execute them.

## Tool Execution Format
All tools must be called using this exact JSON format within code blocks:

```json
{
  "tool_use": true,
  "tool_name": "tool_name_here",
  "parameters": {
    "param1": "value1",
    "param2": "value2"
  }
}
```

## Available Tools

### 1. Screenshot Tool
Takes screenshots of websites using WordPress preview service.

**Example Usage:**
When user says: "Can you take a screenshot of google.com?"

AI should respond:
```json
{
  "tool_use": true,
  "tool_name": "screenshot",
  "parameters": {
    "url": "https://google.com",
    "width": 1200,
    "height": 800
  }
}
```

**Parameters:**
- `url` (required): The website URL to screenshot
- `width` (optional): Screenshot width in pixels (default: 1200)
- `height` (optional): Screenshot height in pixels (default: 800)

### 2. Fetch AI Models Tool
Retrieves the list of available AI models from the API.

**Example Usage:**
When user says: "What AI models are available?"

AI should respond:
```json
{
  "tool_use": true,
  "tool_name": "fetch_ai_models",
  "parameters": {
    "refresh": true,
    "filter": ""
  }
}
```

**Parameters:**
- `refresh` (optional): Force refresh the models list (default: false)
- `filter` (optional): Filter models by name pattern (default: "")

### 3. Switch AI Model Tool
Switches to a different AI model.

**Example Usage:**
When user says: "Switch to GPT-4" or "I want to use Claude instead"

AI should respond:
```json
{
  "tool_use": true,
  "tool_name": "switch_ai_model",
  "parameters": {
    "model_name": "gpt-4-turbo",
    "reason": "User requested GPT-4 for better performance"
  }
}
```

**Parameters:**
- `model_name` (required): Name of the model to switch to
- `reason` (optional): Reason for switching models

## Conversation Examples

### Example 1: Screenshot Request
**User:** "Show me what Flutter's website looks like"

**AI Response:**
I'll take a screenshot of Flutter's website for you.

```json
{
  "tool_use": true,
  "tool_name": "screenshot",
  "parameters": {
    "url": "https://flutter.dev",
    "width": 1200,
    "height": 800
  }
}
```

### Example 2: Model Information Request
**User:** "What models can I choose from?"

**AI Response:**
Let me fetch the current list of available AI models for you.

```json
{
  "tool_use": true,
  "tool_name": "fetch_ai_models",
  "parameters": {
    "refresh": true
  }
}
```

### Example 3: Model Switch Request
**User:** "This model is too slow, switch to something faster"

**AI Response:**
I'll switch to a faster model for you. Let me change to GPT-3.5 Turbo which is known for its speed.

```json
{
  "tool_use": true,
  "tool_name": "switch_ai_model",
  "parameters": {
    "model_name": "gpt-3.5-turbo",
    "reason": "User requested faster model for better response time"
  }
}
```

## Important Notes

### 1. JSON Format Requirements
- Must be within ```json code blocks
- Must include `"tool_use": true`
- Must include valid `tool_name`
- Parameters should be properly formatted JSON

### 2. Tool Execution Results
- Tools execute automatically when JSON is detected
- Results are displayed in a dedicated tool results panel
- Screenshots are shown inline with the chat
- Model switches happen immediately with UI feedback

### 3. Error Handling
- Invalid tool names will show available tools
- Missing required parameters will show error messages
- Network failures are handled gracefully with fallbacks

### 4. User Experience
- Tool execution is seamless and automatic
- Users see real-time loading states
- Success/failure indicators are clearly visible
- All results are expandable/collapsible for better UX

## Testing the Tools

Use the test file `test_external_tools.dart` to verify all tools are working:
- Screenshot tool with WordPress preview
- AI models fetching with API status
- Model switching with real UI updates
- Error handling for invalid inputs

## Tool Capabilities Summary

✅ **Screenshot Tool**: Fully functional with WordPress mshots API
✅ **Fetch AI Models**: Robust API integration with error handling  
✅ **Switch AI Model**: Real-time model switching with UI updates
❌ **Web Search Tool**: Removed as requested
✅ **Error Handling**: Comprehensive validation and fallbacks
✅ **JSON Detection**: Automatic tool execution from responses
✅ **Visual Feedback**: Loading states and result displays