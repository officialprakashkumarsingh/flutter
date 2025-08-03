import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'models/collaboration_models.dart';
import 'models/chat_models.dart';
import 'services/collaboration_service.dart';
import 'services/direct_chat_service.dart';
import 'room_chat_page.dart';
import 'direct_chat_page.dart';

class ChatsPage extends StatefulWidget {
  final String selectedModel;
  
  const ChatsPage({super.key, required this.selectedModel});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> with TickerProviderStateMixin {
  final _collaborationService = CollaborationService();
  final _directChatService = DirectChatService();
  late TabController _tabController;
  
  List<CollaborationRoom> _rooms = [];
  List<DirectChat> _directChats = [];
  List<UserProfile> _searchResults = [];
  bool _isLoading = true;
  String? _error;
  bool _isSearching = false;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeChats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _directChatService.dispose();
    super.dispose();
  }

  Future<void> _initializeChats() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _collaborationService.initialize();
      await _directChatService.initialize();

      final rooms = await _collaborationService.getUserRooms();
      final directChats = await _directChatService.getUserChats();
      
      setState(() {
        _rooms = rooms;
        _directChats = directChats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFFf093fb),
              Color(0xFFf5576c),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildGlassmorphismHeader(),
              Expanded(
                child: _isLoading 
                    ? _buildLoadingState()
                    : _error != null 
                        ? _buildErrorState()
                        : _buildMainContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassmorphismHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Back button with glassmorphism
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  
                  // Title
                  Expanded(
                    child: Text(
                      'Chats',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                            color: Colors.black.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Search button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showUserSearchDialog();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_add,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Tab selector with glassmorphism
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.7),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 16),
                          SizedBox(width: 6),
                          Text('Direct'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.groups_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Rooms'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, size: 16),
                          SizedBox(width: 6),
                          Text('Create'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return Column(
      children: [
        // Custom tab selector
        Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6.resolveFrom(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: CupertinoSlidingSegmentedControl<int>(
            backgroundColor: CupertinoColors.systemGrey6.resolveFrom(context),
            thumbColor: CupertinoColors.systemBackground.resolveFrom(context),
            padding: const EdgeInsets.all(4),
            groupValue: _tabController.index,
            onValueChanged: (value) {
              HapticFeedback.selectionClick();
              _tabController.animateTo(value!);
              setState(() {});
            },
            children: {
              0: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.person_2_fill,
                      size: 16,
                      color: _tabController.index == 0 
                          ? CupertinoColors.systemBlue.resolveFrom(context)
                          : CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'My Rooms',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _tabController.index == 0 
                            ? CupertinoColors.systemBlue.resolveFrom(context)
                            : CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
              1: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.arrow_right_circle_fill,
                      size: 16,
                      color: _tabController.index == 1 
                          ? CupertinoColors.systemBlue.resolveFrom(context)
                          : CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Join Room',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _tabController.index == 1 
                            ? CupertinoColors.systemBlue.resolveFrom(context)
                            : CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF09090B)),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(
              FontAwesomeIcons.triangleExclamation,
              size: 48,
              color: Color(0xFFEF4444),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF09090B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF71717A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildSmallButton(
              onPressed: _initializeCollaboration,
              icon: FontAwesomeIcons.arrowRotateRight,
              text: 'Try Again',
              variant: ButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildMyRoomsTab(),
        _buildJoinRoomTab(),
      ],
    );
  }

  Widget _buildMyRoomsTab() {
    return _rooms.isEmpty 
        ? _buildEmptyRoomsState()
        : _buildModernRoomsList();
  }

  Widget _buildJoinRoomTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGreen.resolveFrom(context),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                CupertinoIcons.arrow_down_right_arrow_up_left,
                size: 36,
                color: CupertinoColors.white,
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              'Join a Room',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Enter a 6-character invite code to join\na room and start collaborating',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: 32),
            
            _buildModernJoinButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernJoinButton() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.lightImpact();
        _showJoinRoomDialog();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGreen.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.arrow_down_right_arrow_up_left,
              color: CupertinoColors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Join with Code',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRoomsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                CupertinoIcons.person_2_fill,
                size: 32,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Conversations',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first room to start\nchatting with friends, family & teams',
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () {
                HapticFeedback.lightImpact();
                _showCreateRoomDialog();
              },
              borderRadius: BorderRadius.circular(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.add,
                    size: 18,
                    color: CupertinoColors.white,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Create Room',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernRoomsList() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildModernRoomCard(_rooms[index]),
              ),
              childCount: _rooms.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        return _buildRoomCard(room);
      },
    );
  }

  Widget _buildRoomCard(CollaborationRoom room) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),

      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          HapticFeedback.lightImpact();
          _joinRoom(room);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Room Avatar - iOS style
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      CupertinoColors.systemBlue.resolveFrom(context),
                      CupertinoColors.systemBlue.resolveFrom(context).withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.person_2_fill,
                  size: 20,
                  color: CupertinoColors.white,
                ),
              ),
              const SizedBox(width: 12),
                
                // Room Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey6,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              room.inviteCode,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.systemBlue.resolveFrom(context),
                                fontFamily: 'Monaco',
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            CupertinoIcons.circle_fill,
                            size: 4,
                            color: CupertinoColors.separator.resolveFrom(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${room.memberCount} members',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // iOS Arrow
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildModernRoomCard(CollaborationRoom room) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.resolveFrom(context).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          HapticFeedback.lightImpact();
          _joinRoom(room);
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Modern Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBlue.resolveFrom(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  CupertinoIcons.group,
                  size: 24,
                  color: CupertinoColors.white,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Room Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    if (room.description != null && room.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        room.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    const SizedBox(height: 8),
                    
                    // Stats Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6.resolveFrom(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.person_2,
                                size: 12,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${room.memberCount}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBlue.resolveFrom(context).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            room.inviteCode,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.systemBlue.resolveFrom(context),
                              fontFamily: 'Monaco',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Action Icon
              Icon(
                CupertinoIcons.chevron_right,
                size: 20,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJoinRoomForm() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),

          ),
          child: TextField(
            controller: _inviteCodeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: GoogleFonts.robotoMono(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF09090B),
              letterSpacing: 1,
            ),
            decoration: InputDecoration(
              hintText: 'Enter invite code',
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF71717A),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        SizedBox(
          width: double.infinity,
          child: _buildSmallButton(
            onPressed: _joinRoomWithCode,
            icon: FontAwesomeIcons.rightToBracket,
            text: 'Join Room',
          ),
        ),
      ],
    );
  }

  // Small button widget
  Widget _buildSmallButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String text,
    ButtonVariant variant = ButtonVariant.primary,
  }) {
    final isPrimary = variant == ButtonVariant.primary;
    
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isPrimary ? CupertinoColors.systemBlue : CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(8),

          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                icon,
                size: 12,
                color: isPrimary ? Colors.white : CupertinoColors.secondaryLabel,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isPrimary ? Colors.white : CupertinoColors.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateRoomDialog() {
    showCupertinoModalPopup(
      context: context,
      barrierDismissible: true,
      builder: (context) => CreateRoomDialog(
        onRoomCreated: (room) {
          setState(() {
            _rooms.insert(0, room);
          });
          Navigator.pushReplacement(
            context,
            CupertinoPageRoute(
              builder: (context) => RoomChatPage(
                room: room, 
                selectedModel: widget.selectedModel,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showJoinRoomDialog() {
    showCupertinoModalPopup(
      context: context,
      barrierDismissible: true,
      builder: (context) => JoinRoomDialog(
        onRoomJoined: (room) {
          setState(() {
            if (!_rooms.any((r) => r.id == room.id)) {
              _rooms.insert(0, room);
            }
          });
          Navigator.pushReplacement(
            context,
            CupertinoPageRoute(
              builder: (context) => RoomChatPage(
                room: room, 
                selectedModel: widget.selectedModel,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _joinRoomWithCode() async {
    final code = _inviteCodeController.text.trim().toUpperCase();
    if (code.length != 6) {
      _showSnackBar('Please enter a valid 6-character invite code', isError: true);
      return;
    }

    try {
      final room = await _collaborationService.joinRoom(code);
      _inviteCodeController.clear();
      
      // Add to rooms list if not already there
      if (!_rooms.any((r) => r.id == room.id)) {
        setState(() {
          _rooms.insert(0, room);
        });
      }
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoomChatPage(
            room: room, 
            selectedModel: widget.selectedModel,
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('Failed to join room: ${e.toString()}', isError: true);
    }
  }

  void _joinRoom(CollaborationRoom room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomChatPage(
          room: room, 
          selectedModel: widget.selectedModel,
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

enum ButtonVariant { primary, secondary }

// iOS-Style Join Room Modal
class JoinRoomDialog extends StatefulWidget {
  final Function(CollaborationRoom) onRoomJoined;

  const JoinRoomDialog({super.key, required this.onRoomJoined});

  @override
  State<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends State<JoinRoomDialog> {
  final _codeController = TextEditingController();
  final _collaborationService = CollaborationService();
  bool _isJoining = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // iOS-style handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isJoining ? null : () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF007AFF),
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Join Room',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isJoining ? null : _joinRoom,
                    child: _isJoining
                        ? const CupertinoActivityIndicator()
                        : const Text(
                            'Join',
                            style: TextStyle(
                              color: Color(0xFF007AFF),
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            
            // Form content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Invite Code Section
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF34C759),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.tickets,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Invite Code',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF8E8E93),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      CupertinoTextField(
                                        controller: _codeController,
                                        placeholder: 'Enter 6-character code',
                                        textCapitalization: TextCapitalization.characters,
                                        maxLength: 6,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          color: Color(0xFF000000),
                                          fontFamily: 'Monaco',
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 2,
                                        ),
                                        decoration: const BoxDecoration(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Info Section
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.info_circle,
                                color: CupertinoColors.systemBlue.resolveFrom(context),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'How it works',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF000000),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Ask your friend to share their 6-character room code. Enter it above to join their conversation and start collaborating with AI together.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E8E93),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    
    if (code.length != 6) {
      _showErrorAlert('Please enter a valid 6-character code');
      return;
    }

    setState(() => _isJoining = true);

    try {
      final room = await _collaborationService.joinRoom(code);
      Navigator.pop(context);
      widget.onRoomJoined(room);
    } catch (e) {
      _showErrorAlert('Failed to join room: ${e.toString()}');
    } finally {
      setState(() => _isJoining = false);
    }
  }

  void _showErrorAlert(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// iOS-Style Create Room Modal
class CreateRoomDialog extends StatefulWidget {
  final Function(CollaborationRoom) onRoomCreated;

  const CreateRoomDialog({super.key, required this.onRoomCreated});

  @override
  State<CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<CreateRoomDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _collaborationService = CollaborationService();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // iOS-style handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isCreating ? null : () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF007AFF),
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'New Room',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isCreating ? null : _createRoom,
                    child: _isCreating
                        ? const CupertinoActivityIndicator()
                        : const Text(
                            'Create',
                            style: TextStyle(
                              color: Color(0xFF007AFF),
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            
            // Form content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Room Name Section
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF007AFF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.group,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Room Name',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF8E8E93),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      CupertinoTextField(
                                        controller: _nameController,
                                        placeholder: 'Enter room name',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          color: Color(0xFF000000),
                                        ),
                                        decoration: const BoxDecoration(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Description Section
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                CupertinoIcons.doc_text,
                                color: Color(0xFF8E8E93),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Description (Optional)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8E8E93),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          CupertinoTextField(
                            controller: _descriptionController,
                            placeholder: 'What will you be working on together?',
                            maxLines: 3,
                            style: const TextStyle(
                              fontSize: 17,
                              color: Color(0xFF000000),
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(12),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createRoom() async {
    if (_nameController.text.trim().isEmpty) {
      _showErrorAlert('Please enter a room name');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final request = CreateRoomRequest(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
      );

      final room = await _collaborationService.createRoom(request);
      Navigator.pop(context);
      widget.onRoomCreated(room);
    } catch (e) {
      _showErrorAlert('Failed to create room: ${e.toString()}');
    } finally {
      setState(() => _isCreating = false);
    }
  }

  void _showErrorAlert(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}