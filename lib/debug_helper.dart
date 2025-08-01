import 'package:supabase_flutter/supabase_flutter.dart';

class DebugHelper {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  static Future<void> testDatabaseConnectivity() async {
    print('🔧 DEBUG: Testing database connectivity...');
    
    try {
      // Test 1: Check user authentication
      final user = _supabase.auth.currentUser;
      print('🔧 DEBUG: User authenticated: ${user != null ? user.id : 'NO'}');
      
      if (user == null) {
        print('❌ DEBUG: Cannot test database - user not authenticated');
        return;
      }
      
      // Test 2: Check if profiles table exists and user profile exists
      try {
        final profileResponse = await _supabase
            .from('profiles')
            .select('id, email')
            .eq('id', user.id)
            .maybeSingle();
        
        if (profileResponse != null) {
          print('✅ DEBUG: User profile exists: ${profileResponse['email']}');
        } else {
          print('❌ DEBUG: User profile does not exist');
        }
      } catch (e) {
        print('❌ DEBUG: Error checking profiles table: $e');
      }
      
      // Test 3: Check if characters table exists
      try {
        final charactersResponse = await _supabase
            .from('characters')
            .select('id, name, is_built_in')
            .eq('user_id', user.id);
        
        print('✅ DEBUG: Characters table accessible, found ${charactersResponse.length} characters');
        for (var char in charactersResponse) {
          print('   - ${char['name']} (built-in: ${char['is_built_in']})');
        }
      } catch (e) {
        print('❌ DEBUG: Error accessing characters table: $e');
      }
      
      // Test 4: Check if chat_conversations table exists
      try {
        final conversationsResponse = await _supabase
            .from('chat_conversations')
            .select('id, title')
            .eq('user_id', user.id)
            .limit(5);
        
        print('✅ DEBUG: Chat conversations table accessible, found ${conversationsResponse.length} conversations');
        for (var conv in conversationsResponse) {
          print('   - ${conv['title']}');
        }
      } catch (e) {
        print('❌ DEBUG: Error accessing chat_conversations table: $e');
      }
      
      // Test 5: Try creating a test character
      try {
        print('🔧 DEBUG: Attempting to create test character...');
        final testCharResponse = await _supabase
            .from('characters')
            .insert({
              'user_id': user.id,
              'name': 'DEBUG_TEST_CHARACTER',
              'description': 'Test character for debugging',
              'system_prompt': 'Test prompt',
              'is_built_in': false,
            })
            .select('id')
            .single();
        
        final testId = testCharResponse['id'];
        print('✅ DEBUG: Successfully created test character with ID: $testId');
        
        // Clean up test character
        await _supabase
            .from('characters')
            .delete()
            .eq('id', testId);
        print('✅ DEBUG: Test character cleaned up');
        
      } catch (e) {
        print('❌ DEBUG: Error creating test character: $e');
      }
      
    } catch (e) {
      print('❌ DEBUG: General database connectivity error: $e');
    }
  }
}