import 'dart:convert';
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
import 'auth_service.dart';
import 'auth_and_profile_pages.dart';
import 'external_tools_service.dart';

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

  // State for model selection
  List<String> _models = [];
  String _selectedModel = 'claude-3-7-sonnet'; 
  bool _isLoadingModels = true;
  
  // State for temporary chat mode
  bool _isTemporaryChatMode = false;

  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  late AnimationController _pageTransitionController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fetchModels();
    
    // Set up external tools callback for model switching
    ExternalToolsService().setModelSwitchCallback(switchModel);
    
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
    _fabAnimationController.dispose();
    _pageTransitionController.dispose();
    super.dispose();
  }

  /// Switch to a different AI model (called by external tools)
  void switchModel(String modelName) {
    if (_models.contains(modelName)) {
      setState(() => _selectedModel = modelName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🔄 Switched to $_selectedModel',
            style: const TextStyle(
              color: Color(0xFF000000),
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          elevation: 4,
          duration: const Duration(seconds: 2),
        ),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEAE9E5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
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
                                border: isSelected ? Border.all(color: const Color(0xFF000000), width: 1) : null,
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '✅ $_selectedModel selected',
                                        style: const TextStyle(
                                          color: Color(0xFF000000),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      backgroundColor: Colors.white,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      margin: const EdgeInsets.all(16),
                                      elevation: 4,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
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
    
    // Only save chat history if NOT in temporary chat mode
    if (!_isTemporaryChatMode && currentMessages != null && currentMessages.length > 1) {
      final lastUserMessage = currentMessages.lastWhere((m) => m.sender == Sender.user, orElse: () => Message.user(''));

      if (lastUserMessage.text.isNotEmpty) {
        final title = lastUserMessage.text.length <= 20
            ? lastUserMessage.text
            : '${lastUserMessage.text.substring(0, 20)}...';
        
        final session = ChatSession(
          title: title,
          messages: List.from(currentMessages),
        );
        setState(() {
          _chatHistory.insert(0, session);
        });
      }
    }

    _chatPageKey.currentState?.startNewChat();
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
    }
  }
  
  void _loadChat(ChatSession session) {
    _chatPageKey.currentState?.loadChatSession(session.messages);
    setState(() {
      _selectedIndex = 0;
    });
    Navigator.pop(context); // Close sidebar
  }

  void _deleteChat(ChatSession session) {
    setState(() {
      _chatHistory.remove(session);
    });
  }

  void _pinChat(ChatSession session) {
    // Move to top of list
    setState(() {
      _chatHistory.remove(session);
      _chatHistory.insert(0, session);
    });
    _showSnackBar('📌 Chat pinned to top');
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
                leading: const Icon(Icons.push_pin_outlined, color: Color(0xFF000000)),
                title: const Text('Pin Chat'),
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
            ValueListenableBuilder<User?>(
              valueListenable: AuthService().currentUser,
              builder: (context, user, child) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAE9E5),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            user?.email.isNotEmpty == true ? user!.email[0].toUpperCase() : 'U',
                            style: GoogleFonts.inter(
                              fontSize: 20,
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
                              user?.name ?? 'User',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF000000),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFFA3A3A3),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  const ProfilePage(),
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
                        icon: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFA3A3A3), size: 16),
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
                      fontSize: 20,
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
                        const Icon(Icons.groups_rounded, color: Color(0xFF000000), size: 22),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Characters',
                            style: TextStyle(
                              fontSize: 16,
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
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF000000),
                    ),
                  ),
                  const Spacer(),
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
            
            // Chat History List
            Expanded(
              child: _chatHistory.isEmpty
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
                              fontSize: 16,
                              color: const Color(0xFFA3A3A3),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _chatHistory.length,
                      itemBuilder: (context, index) {
                        final session = _chatHistory[index];
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
          selectedModel: _selectedModel
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