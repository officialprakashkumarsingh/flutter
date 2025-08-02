import 'lib/agents/curl_agent.dart';

void main() async {
  print('🔍 Debugging Authorization Issue...');
  
  // Test the exact working command from before
  final workingCommand = 'curl https://ahamai-api.officialprakashkrsingh.workers.dev/v1/models -H "Authorization: Bearer ahamaibyprakash25"';
  
  print('📝 Testing WORKING command: $workingCommand');
  print('');
  
  // Test execution
  print('🚀 Executing models curl...');
  final result1 = await CurlAgent.executeCurl(workingCommand);
  print('📊 Models Result:');
  print(result1?.substring(0, 200) ?? 'No result');
  print('\n' + '='*50 + '\n');
  
  // Test chat command that's failing
  final chatCommand = 'curl -X POST https://ahamai-api.officialprakashkrsingh.workers.dev/v1/chat/completions -H "Content-Type: application/json" -H "Authorization: Bearer ahamaibyprakash25" -d \'{"model": "claude-4-sonnet", "messages": [{"role": "user", "content": "Hello"}]}\'';
  
  print('📝 Testing CHAT command: $chatCommand');
  print('');
  
  print('🚀 Executing chat curl...');
  final result2 = await CurlAgent.executeCurl(chatCommand);
  print('📊 Chat Result:');
  print(result2?.substring(0, 300) ?? 'No result');
}