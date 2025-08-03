import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/collaboration_models.dart';
import 'services/collaboration_service.dart';
import 'room_chat_page.dart';

// Custom text formatter for uppercase input
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class ChatsPage extends StatefulWidget {
  final String selectedModel;
  
  const ChatsPage({super.key, required this.selectedModel});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final _collaborationService = CollaborationService();
  
  List<CollaborationRoom> _rooms = [];
  List<CollaborationRoom> _filteredRooms = [];
  bool _isLoading = true;
  String _searchText = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
        _filterRooms();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    try {
      setState(() => _isLoading = true);
      final rooms = await _collaborationService.getUserRooms();
      setState(() {
        _rooms = rooms;
        _filteredRooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading rooms: $e');
    }
  }

  void _filterRooms() {
    if (_searchText.isEmpty) {
      _filteredRooms = _rooms;
    } else {
      _filteredRooms = _rooms.where((room) =>
          room.name.toLowerCase().contains(_searchText.toLowerCase())).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFE4E4E7),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Action Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Collabs',
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF09090B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create or join collaboration rooms to work together',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFF71717A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Action Buttons
                    Row(
                      children: [
                        _buildActionButton(
                          'Join Room',
                          Icons.group_add_rounded,
                          () => _showJoinRoomDialog(),
                        ),
                        const SizedBox(width: 12),
                        _buildActionButton(
                          'Create Room',
                          Icons.add_circle_outline_rounded,
                          () => _showCreateRoomDialog(),
                          isPrimary: true,
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Search Bar - Prominently positioned
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE4E4E7),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF09090B).withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: const Color(0xFF09090B),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search collaboration rooms...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 15,
                        color: const Color(0xFF71717A),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF71717A),
                        size: 22,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchText = '';
                                  _filterRooms();
                                });
                              },
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: Color(0xFF71717A),
                                size: 20,
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content Area
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF09090B)),
                    ),
                  )
                : _filteredRooms.isEmpty
                    ? _buildEmptyState()
                    : Column(
                        children: [
                          // Room Count Header
                          Container(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                            child: Row(
                              children: [
                                Text(
                                  '${_filteredRooms.length} ${_filteredRooms.length == 1 ? 'Room' : 'Rooms'}${_searchText.isNotEmpty ? ' found' : ''}',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF09090B),
                                  ),
                                ),
                                if (_searchText.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE4E4E7),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'for "$_searchText"',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF71717A),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Rooms List
                          Expanded(child: _buildRoomsList()),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    bool isPrimary = false,
    bool isLarge = false,
  }) {
    return Container(
      height: isLarge ? 52 : 44,
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFF09090B) : Colors.white,
        borderRadius: BorderRadius.circular(isLarge ? 12 : 8),
        border: Border.all(
          color: const Color(0xFFE4E4E7),
          width: 1,
        ),
        boxShadow: isLarge ? [
          BoxShadow(
            color: const Color(0xFF09090B).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(isLarge ? 12 : 8),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isLarge ? 24 : 16),
            child: Row(
              mainAxisSize: isLarge ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: isLarge ? 20 : 18,
                  color: isPrimary ? Colors.white : const Color(0xFF09090B),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: isLarge ? 16 : 14,
                    fontWeight: FontWeight.w500,
                    color: isPrimary ? Colors.white : const Color(0xFF09090B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Enhanced Empty State Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFF8F9FA),
                    const Color(0xFFF1F5F9),
                  ],
                ),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(
                  color: const Color(0xFFE4E4E7),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF09090B).withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.groups_rounded,
                size: 50,
                color: Color(0xFF71717A),
              ),
            ),
            const SizedBox(height: 32),
            
            // Enhanced Title
            Text(
              'Start Collaborating',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF09090B),
              ),
            ),
            const SizedBox(height: 12),
            
            // Enhanced Description
            Text(
              'No collaboration rooms yet. Create your first room or\njoin an existing one to start working together.',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF71717A),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            
            // Enhanced Action Buttons
            Column(
              children: [
                SizedBox(
                  width: 280,
                  child: _buildActionButton(
                    'Create Your First Room',
                    Icons.add_circle_outline_rounded,
                    () => _showCreateRoomDialog(),
                    isPrimary: true,
                    isLarge: true,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 280,
                  child: _buildActionButton(
                    'Join Existing Room',
                    Icons.group_add_rounded,
                    () => _showJoinRoomDialog(),
                    isLarge: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomsList() {
    return RefreshIndicator(
      onRefresh: _loadRooms,
      color: const Color(0xFF09090B),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: _filteredRooms.length,
        itemBuilder: (context, index) => _buildRoomCard(_filteredRooms[index]),
      ),
    );
  }

  Widget _buildRoomCard(CollaborationRoom room) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE4E4E7),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF09090B).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
              child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _joinRoomChat(room),
            borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE4E4E7),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: Color(0xFF09090B),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.name,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF09090B),
                            ),
                          ),
                          if (room.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              room.description!,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF71717A),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE4E4E7),
                          width: 1,
                        ),
                      ),
                                             child: Text(
                         room.inviteCode,
                         style: GoogleFonts.spaceMono(
                           fontSize: 12,
                           fontWeight: FontWeight.w600,
                           color: const Color(0xFF09090B),
                         ),
                       ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 16,
                      color: const Color(0xFF71717A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${room.memberCount} members',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF71717A),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: const Color(0xFF71717A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(room.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _joinRoomChat(CollaborationRoom room) {
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

  void _showJoinRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => JoinRoomDialog(
        onRoomJoined: (room) {
          setState(() {
            if (!_rooms.any((r) => r.id == room.id)) {
              _rooms.insert(0, room);
              _filterRooms();
            }
          });
          _joinRoomChat(room);
        },
      ),
    );
  }

  void _showCreateRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateRoomDialog(
        onRoomCreated: (room) {
          setState(() {
            _rooms.insert(0, room);
            _filterRooms();
          });
          _joinRoomChat(room);
        },
      ),
    );
  }

  void _showErrorAlert(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// Join Room Dialog
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE4E4E7),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.group_add_rounded,
                      color: Color(0xFF09090B),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Join Room',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF09090B),
                          ),
                        ),
                        Text(
                          'Enter the 6-character room code',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF71717A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF71717A),
                      size: 20,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE4E4E7),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF09090B).withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.spaceMono(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF000000), // Pure black for better visibility
                    letterSpacing: 6,
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(6),
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                    UpperCaseTextFormatter(), // Custom formatter for uppercase
                  ],
                  decoration: InputDecoration(
                    hintText: 'ABC123',
                    hintStyle: GoogleFonts.spaceMono(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFFBBBBBB), // Lighter hint color
                      letterSpacing: 6,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isJoining ? const Color(0xFFF8F9FA) : const Color(0xFF09090B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE4E4E7),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isJoining ? null : _joinRoom,
                      borderRadius: BorderRadius.circular(8),
                      child: Center(
                        child: _isJoining
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF71717A)),
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Join Room',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// Create Room Dialog
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE4E4E7),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Color(0xFF09090B),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Room',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF09090B),
                          ),
                        ),
                        Text(
                          'Start a new collaboration room',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF71717A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF71717A),
                      size: 20,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Room Name',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF09090B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE4E4E7),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _nameController,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF09090B),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter room name',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF71717A),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description (Optional)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF09090B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE4E4E7),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: null,
                      expands: true,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF09090B),
                      ),
                      decoration: InputDecoration(
                        hintText: 'What\'s this room about?',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF71717A),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isCreating ? const Color(0xFFF8F9FA) : const Color(0xFF09090B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE4E4E7),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isCreating ? null : _createRoom,
                      borderRadius: BorderRadius.circular(8),
                      child: Center(
                        child: _isCreating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF71717A)),
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Create Room',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}