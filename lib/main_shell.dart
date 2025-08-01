import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'chat_page.dart';
import 'characters_page.dart';
import 'saved_page.dart';
import 'models.dart';
import 'supabase_auth_service.dart';
import 'supabase_chat_service.dart';
import 'supabase_character_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added for AuthState
// REMOVED: External tools service import

// Custom rounded SnackBar utility
void showRoundedSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: GoogleFonts.inter(
          color: const Color(0xFF000000),
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      backgroundColor: isError ? const Color(0xFFFFE5E5) : const Color(0xFFE8F5E8),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isError ? const Color(0xFFFF6B6B) : const Color(0xFF4CAF50),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.only(
        bottom: 80, // Position above bottom navigation
        left: 16,
        right: 16,
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}


/* ----------------------------------------------------------
   MAIN SHELL (Tab Navigation)
---------------------------------------------------------- */
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  final GlobalKey<ChatPageState> _chatPageKey = GlobalKey<ChatPageState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Message> _bookmarkedMessages = [];
  final List<ChatSession> _chatHistory = [];

  // Search query for chat history
  String _chatSearchQuery = '';

  List<ChatSession> get _filteredChatHistory {
    if (_chatSearchQuery.isEmpty) return _chatHistory;
    final query = _chatSearchQuery.toLowerCase();
    return _chatHistory.where((chat) => chat.title.toLowerCase().contains(query)).toList();
  }

  // State for model selection
  List<String> _models = [];
  String _selectedModel = 'claude-3-7-sonnet'; 
  bool _isLoadingModels = true;
  
  // State for temporary chat mode
  bool _isTemporaryChatMode = false;

  // State for chat history loading
  bool _isLoadingChatHistory = false;
  DateTime? _lastChatHistoryLoad;

  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  late AnimationController _pageTransitionController;
  late Animation<Offset> _slideAnimation;

  // Auth state listener
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _fetchModels();
    
    // Listen for auth state changes
    _authSubscription = SupabaseAuthService.authStateChanges.listen((authState) {
      // Only clear chat history when user signs out
      // Don't reload on sign in to prevent duplicates (initState handles initial load)
      if (!SupabaseAuthService.isSignedIn) {
        debugPrint('🚪 AUTH STATE: User signed out, starting cleanup...');
        // Clear chat history when user signs out
        setState(() {
          _chatHistory.clear();
        });
        _lastChatHistoryLoad = null; // Reset debounce timer
        
        // Clear the current active chat to prevent it from being saved as "New Chat"
        debugPrint('🧹 AUTH STATE: Calling startNewChat to clear active conversation...');
        _chatPageKey.currentState?.startNewChat();
        
        debugPrint('✅ AUTH STATE: User signed out cleanup completed');
      } else {
        debugPrint('🔑 AUTH STATE: User signed in, but NOT auto-loading chat history to prevent duplicates');
        debugPrint('🔑 AUTH STATE: Current chat history count: ${_chatHistory.length}');
        // REMOVED: Auto-loading on auth state change to prevent duplicates
        // Chat history will be loaded by the initial load in initState() only
      }
    });
    
    // Load chat history only if user is already signed in AND we don't have any yet
    if (SupabaseAuthService.isSignedIn && _chatHistory.isEmpty) {
      debugPrint('🚀 INIT: User already signed in, loading chat history...');
      _loadChatHistoryFromSupabase();
    } else if (SupabaseAuthService.isSignedIn) {
      debugPrint('🚀 INIT: User signed in but already have ${_chatHistory.length} chats, skipping initial load');
    }
    
    // Set up external tools callback for model switching
    // REMOVED: External tools service model switch callback
    
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    );
    
    _pageTransitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageTransitionController,
      curve: Curves.easeOutCubic,
    ));
    
    _fabAnimationController.forward();
    _pageTransitionController.forward();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _fabAnimationController.dispose();
    _pageTransitionController.dispose();
    super.dispose();
  }

  // Load chat history from Supabase
  Future<void> _loadChatHistoryFromSupabase() async {
    // Prevent multiple simultaneous loads
    if (_isLoadingChatHistory) {
      debugPrint('🔄 Chat history already loading, skipping...');
      return;
    }
    
    // Stronger debounce: prevent calls within 3 seconds of each other
    final now = DateTime.now();
    if (_lastChatHistoryLoad != null && 
        now.difference(_lastChatHistoryLoad!).inMilliseconds < 3000) {
      debugPrint('⏰ Chat history loaded recently (${now.difference(_lastChatHistoryLoad!).inMilliseconds}ms ago), skipping debounced call...');
      return;
    }
    
    // Additional check: if we already have the same number of conversations, skip
    if (_chatHistory.isNotEmpty) {
      final currentCount = _chatHistory.length;
      debugPrint('📊 Current chat history count: $currentCount, checking if reload needed...');
    }
    
    _isLoadingChatHistory = true;
    _lastChatHistoryLoad = now;
    
    try {
      debugPrint('🚀 Starting chat history load from Supabase...');
      debugPrint('📊 Current _chatHistory size BEFORE load: ${_chatHistory.length}');
      
      final conversations = await SupabaseChatService.getUserConversations();
      
      debugPrint('📥 SupabaseChatService returned ${conversations.length} conversations');
      
      if (conversations.isNotEmpty) {
        final List<ChatSession> loadedHistory = [];
        final Set<String> seenIds = {}; // Track seen conversation IDs
        
        debugPrint('🔍 Processing ${conversations.length} conversations...');
        
        for (final conversation in conversations) {
          final conversationId = conversation['id'] as String;
          
          debugPrint('🔍   Processing conversation ID: $conversationId, Title: ${conversation['title']}');
          
          // Skip if we've already processed this conversation ID in this batch
          if (seenIds.contains(conversationId)) {
            debugPrint('⚠️   Skipping duplicate conversation ID in batch: $conversationId');
            continue;
          }
          seenIds.add(conversationId);
          
          final fullConversation = await SupabaseChatService.loadConversation(conversationId);
          if (fullConversation != null) {
            final session = ChatSession(
              id: fullConversation['id'],
              title: fullConversation['title'],
              messages: List<Message>.from(fullConversation['messages']),
              createdAt: fullConversation['createdAt'],
              updatedAt: fullConversation['updatedAt'],
              isPinned: fullConversation['isPinned'] ?? false,
              pinnedAt: fullConversation['pinnedAt'],
            );
            loadedHistory.add(session);
            debugPrint('✅   Added session: ${session.title} with ${session.messages.length} messages (pinned: ${session.isPinned})');
          } else {
            debugPrint('❌   Failed to load full conversation for ID: $conversationId');
          }
        }
        
        debugPrint('📝 Loaded ${loadedHistory.length} unique sessions, replacing existing ${_chatHistory.length} sessions');
        
        setState(() {
          _chatHistory.clear(); // Clear existing to prevent duplicates
          _chatHistory.addAll(loadedHistory);
        });
        
        debugPrint('✅ Successfully loaded ${_chatHistory.length} unique chat sessions from Supabase');
        debugPrint('📊 Final _chatHistory contents:');
        for (var i = 0; i < _chatHistory.length; i++) {
          debugPrint('📊   [$i] ID: ${_chatHistory[i].id}, Title: ${_chatHistory[i].title}');
        }
        
      } else {
        // No conversations found, clear the list
        debugPrint('📭 No conversations found in Supabase, clearing ${_chatHistory.length} existing sessions');
        setState(() {
          _chatHistory.clear();
        });
        debugPrint('🧹 Cleared chat history - now empty');
      }
    } catch (e) {
      debugPrint('❌ Error loading chat history from Supabase: $e');
      // Clear on error to prevent stale data
      setState(() {
        _chatHistory.clear();
      });
    } finally {
      _isLoadingChatHistory = false;
      debugPrint('🏁 Chat history loading completed');
    }
  }

  // Refresh chat history from Supabase
  Future<void> _refreshChatHistory() async {
    await _loadChatHistoryFromSupabase();
  }

  // Manual refresh that bypasses debouncing (for user-initiated refresh)
  Future<void> _manualRefreshChatHistory() async {
    debugPrint('Manual refresh requested by user, bypassing debounce...');
    _lastChatHistoryLoad = null; // Reset debounce to allow immediate load
    await _loadChatHistoryFromSupabase();
  }

  /// Switch to a different AI model (called by external tools)
  void switchModel(String modelName) {
    if (_models.contains(modelName)) {
      setState(() => _selectedModel = modelName);
      showRoundedSnackBar(context, '🔄 Switched to $_selectedModel');
    }
  }

  Future<void> _fetchModels() async {
    try {
      final response = await http.get(
        Uri.parse('https://ahamai-api.officialprakashkrsingh.workers.dev/v1/models'),
        headers: {'Authorization': 'Bearer ahamaibyprakash25'},
      );
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        final models = (data['data'] as List).map<String>((item) => item['id']).toList();
        setState(() {
          _models = models;
          if (!_models.contains(_selectedModel) && _models.isNotEmpty) {
            _selectedModel = _models.first;
          }
          _isLoadingModels = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoadingModels = false);
        _showSnackBar('Error fetching models: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingModels = false);
      _showSnackBar('Failed to fetch models: $e');
    }
  }

  void _showSnackBar(String message) {
    showRoundedSnackBar(context, message);
  }

  void _showModelSelectionSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF4F3F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC4C4C4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        'Select AI Model',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF000000),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFFA3A3A3)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                LimitedBox(
                  maxHeight: 400,
                  child: _isLoadingModels
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(color: Color(0xFF000000)),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _models.length,
                          itemBuilder: (context, index) {
                            final model = _models[index];
                            final isSelected = _selectedModel == model;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFEAE9E5) : const Color(0xFFF4F3F0),
                                borderRadius: BorderRadius.circular(12),
                                // Tick icon already shows selection; border removed for cleaner look
                                border: null,
                              ),
                              child: ListTile(
                                title: Text(
                                  model,
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFF000000) : const Color(0xFF000000),
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                                trailing: isSelected 
                                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF000000))
                                    : null,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedModel = model);
                                  Navigator.pop(context);
                                  showRoundedSnackBar(context, '✅ $_selectedModel selected');
                                },
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _bookmarkMessage(Message botMessage) {
    setState(() {
      if (!_bookmarkedMessages.any((m) => m.text == botMessage.text)) {
        _bookmarkedMessages.insert(0, botMessage);
        _showSnackBar('💾 AI response saved!');
      } else {
        _showSnackBar('ℹ️ This response is already saved.');
      }
    });
  }

  void _saveAndStartNewChat() {
    final currentMessages = _chatPageKey.currentState?.getMessages();
    
    // Duplicate-prevention:
    // ChatPage already calls SupabaseChatService.saveConversation (insert on first save, then update).
    // The additional save here inserted a *second* row with a new UUID, which caused duplicate
    // conversation entries to appear after the next login. We therefore remove the extra save.
    // (If you later need auto-save logic here, be sure to pass the existing conversationId.)

    _chatPageKey.currentState?.startNewChat();
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
    }
  }

  // Save chat session to Supabase
  Future<void> _saveChatToSupabase(List<Message> messages, String title) async {
    try {
      final conversationId = await SupabaseChatService.saveConversation(
        messages: messages,
        conversationMemory: [],
        title: title,
      );
      
      if (conversationId != null) {
        debugPrint('Chat saved to Supabase with ID: $conversationId');
        // Note: ChatPage will handle the refresh via onChatHistoryChanged callback
        // No need to refresh here to prevent duplicate calls
      }
    } catch (e) {
      debugPrint('Error saving chat to Supabase: $e');
    }
  }
  
  void _loadChat(ChatSession session) {
    _chatPageKey.currentState?.loadChatSession(session.messages, conversationId: session.id);
    setState(() {
      _selectedIndex = 0;
    });
    Navigator.pop(context); // Close sidebar
  }

  void _deleteChat(ChatSession session) {
    setState(() {
      _chatHistory.remove(session);
    });
    
    // Also delete from Supabase if it has an ID
    if (session.id != null) {
      _deleteChatFromSupabase(session.id!);
    }
  }

  // Delete chat from Supabase
  Future<void> _deleteChatFromSupabase(String conversationId) async {
    try {
      final success = await SupabaseChatService.deleteConversation(conversationId);
      if (success) {
        debugPrint('Chat deleted from Supabase: $conversationId');
      }
    } catch (e) {
      debugPrint('Error deleting chat from Supabase: $e');
    }
  }

  void _pinChat(ChatSession session) async {
    try {
      // Toggle pin status
      final newPinStatus = !session.isPinned;
      
      // Update in Supabase
      final success = await SupabaseChatService.pinConversation(session.id, newPinStatus);
      
      if (success) {
        // Update local state
        final updatedSession = session.copyWith(
          isPinned: newPinStatus,
          pinnedAt: newPinStatus ? DateTime.now() : null,
        );
        
        setState(() {
          final index = _chatHistory.indexWhere((chat) => chat.id == session.id);
          if (index != -1) {
            _chatHistory[index] = updatedSession;
            // Re-sort to put pinned chats at top
            _chatHistory.sort((a, b) {
              if (a.isPinned && !b.isPinned) return -1;
              if (!a.isPinned && b.isPinned) return 1;
              if (a.isPinned && b.isPinned) {
                return b.pinnedAt!.compareTo(a.pinnedAt!);
              }
              return b.updatedAt.compareTo(a.updatedAt);
            });
          }
        });
        
        _showSnackBar(newPinStatus ? '📌 Chat pinned' : '📌 Chat unpinned');
      } else {
        showRoundedSnackBar(context, '❌ Failed to pin chat', isError: true);
      }
    } catch (e) {
      debugPrint('❌ Error pinning chat: $e');
      showRoundedSnackBar(context, '❌ Failed to pin chat', isError: true);
    }
  }

  void _showChatOptions(ChatSession session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF4F3F0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFC4C4C4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(
                  session.isPinned ? Icons.push_pin : Icons.push_pin_outlined, 
                  color: session.isPinned ? const Color(0xFF4CAF50) : const Color(0xFF000000)
                ),
                title: Text(session.isPinned ? 'Unpin Chat' : 'Pin Chat'),
                onTap: () {
                  Navigator.pop(context);
                  _pinChat(session);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Chat', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteChat(session);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar() {
    return Drawer(
      backgroundColor: const Color(0xFFF4F3F0),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Profile Section
            StreamBuilder(
              stream: SupabaseAuthService.authStateChanges,
              builder: (context, snapshot) {
                final user = SupabaseAuthService.currentUser;
                final userEmail = user?.email ?? '';
                final userName = SupabaseAuthService.userFullName ?? userEmail.split('@').first;
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAE9E5),
                          borderRadius: BorderRadius.circular(21),
                        ),
                        child: Center(
                          child: Text(
                            userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'U',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF000000),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF000000),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userEmail,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFFA3A3A3),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          // Show logout confirmation
                          final shouldLogout = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFFF4F3F0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Text(
                                'Sign Out',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF000000),
                                ),
                              ),
                              content: Text(
                                'Are you sure you want to sign out?',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF666666),
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B6B),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF6B6B).withOpacity(0.3),
                                        offset: const Offset(0, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      backgroundColor: Colors.transparent,
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      'Sign Out',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFFFFFFFF),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                          
                          if (shouldLogout == true) {
                            await SupabaseAuthService.signOut();
                          }
                        },
                        icon: const FaIcon(FontAwesomeIcons.rightFromBracket, color: Color(0xFFA3A3A3), size: 16),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Menu',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF000000),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF000000)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Characters option
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Material(
                color: const Color(0xFFEAE9E5),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            CharactersPage(selectedModel: _selectedModel),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1.0, 0.0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: child,
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 300),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.userGroup, color: Color(0xFF000000), size: 20),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Characters',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF000000),
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFA3A3A3), size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            
            const SizedBox(height: 16),
            
            // Chat History Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Chat History',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF000000),
                    ),
                  ),
                  const Spacer(),
                  // Refresh button
                  GestureDetector(
                    onTap: _manualRefreshChatHistory,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0DED9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_chatHistory.length}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFFA3A3A3),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Chat History Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0DED9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _chatSearchQuery = value),
                  style: const TextStyle(color: Color(0xFF000000), fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search chats...',
                    hintStyle: TextStyle(color: Color(0xFFA3A3A3), fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: Color(0xFFA3A3A3), size: 18),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Chat History List
            Expanded(
              child: _filteredChatHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: const Color(0xFFA3A3A3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No chat history yet',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFFA3A3A3),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _filteredChatHistory.length,
                      itemBuilder: (context, index) {
                        final session = _filteredChatHistory[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => _loadChat(session),
                              onLongPress: () => _showChatOptions(session),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Pin icon
                                    if (session.isPinned)
                                      Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        child: Icon(
                                          Icons.push_pin,
                                          color: const Color(0xFF4CAF50),
                                          size: 16,
                                        ),
                                      ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            session.title,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF000000),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${session.messages.length} messages',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: const Color(0xFFA3A3A3),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _showChatOptions(session),
                                      icon: const Icon(
                                        Icons.more_vert_rounded,
                                        color: Color(0xFFA3A3A3),
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      drawer: _buildSidebar(),
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showModelSelectionSheet,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isTemporaryChatMode)
                Text(
                  'private',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF000000),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AhamAI',
                    style: GoogleFonts.spaceMono(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF000000),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFFA3A3A3),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Scaffold.of(context).openDrawer();
              },
              child: Container(
                width: 36,
                height: 36,
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.bars,
                    color: Color(0xFF000000),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: [
          // Temporary chat toggle button with incognito icon
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ScaleTransition(
              scale: _fabAnimation,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isTemporaryChatMode = !_isTemporaryChatMode;
                      });
                      
                      // Clear current chat and reload based on new mode
                      _chatPageKey.currentState?.startNewChat();
                      
                      // Show feedback to user
                      showRoundedSnackBar(
                        context,
                        _isTemporaryChatMode 
                          ? '🎭 Temporary chat mode enabled - conversations won\'t be saved'
                          : '💾 Normal chat mode enabled - conversations will be saved'
                      );
                    },
                    borderRadius: BorderRadius.circular(21),
                    child: FaIcon(
                      FontAwesomeIcons.mask,
                      color: _isTemporaryChatMode ? const Color(0xFF000000) : const Color(0xFFA3A3A3),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // New chat button
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: ScaleTransition(
              scale: _fabAnimation,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _saveAndStartNewChat();
                    },
                    borderRadius: BorderRadius.circular(21),
                    child: const FaIcon(
                      FontAwesomeIcons.commentDots,
                      color: Color(0xFFA3A3A3),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SlideTransition(
        position: _slideAnimation,
        child: ChatPage(
          key: _chatPageKey, 
          onBookmark: _bookmarkMessage, 
          selectedModel: _selectedModel,
          onChatHistoryChanged: _refreshChatHistory, // Add callback
          isTemporaryChatMode: _isTemporaryChatMode, // Pass temporary chat mode state
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------
   PLACEHOLDER PAGE for other tabs
---------------------------------------------------------- */
class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title Page',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: const Color(0xFFA3A3A3)),
      ),
    );
  }
}