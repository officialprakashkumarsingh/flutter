import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'models/collaboration_models.dart';
import 'services/collaboration_service.dart';
import 'room_chat_page.dart';

class CollaborationPage extends StatefulWidget {
  final String selectedModel;
  
  const CollaborationPage({super.key, required this.selectedModel});

  @override
  State<CollaborationPage> createState() => _CollaborationPageState();
}

class _CollaborationPageState extends State<CollaborationPage> with TickerProviderStateMixin {
  final _collaborationService = CollaborationService();
  late TabController _tabController;
  
  List<CollaborationRoom> _rooms = [];
  bool _isLoading = true;
  String? _error;
  
  final TextEditingController _inviteCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeCollaboration();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _initializeCollaboration() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _collaborationService.initialize();

      final rooms = await _collaborationService.getUserRooms();
      setState(() {
        _rooms = rooms;
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
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _isLoading 
          ? _buildLoadingState()
          : _error != null 
              ? _buildErrorState()
              : _buildMainContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const FaIcon(FontAwesomeIcons.arrowLeft, color: Color(0xFF09090B), size: 18),
      ),
      title: Text(
        'Collaborate',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF09090B),
        ),
      ),
      actions: [
        // Add create room button in header (only one place)
        if (_tabController.index == 0)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildSmallButton(
              onPressed: _showCreateRoomDialog,
              icon: FontAwesomeIcons.plus,
              text: 'Create',
            ),
          ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF09090B),
        indicatorWeight: 2,
        labelColor: const Color(0xFF09090B),
        unselectedLabelColor: const Color(0xFF71717A),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        onTap: (index) => setState(() {}), // Rebuild to show/hide create button
        tabs: const [
          Tab(icon: FaIcon(FontAwesomeIcons.users, size: 16), text: 'My Rooms'),
          Tab(icon: FaIcon(FontAwesomeIcons.rightToBracket, size: 16), text: 'Join Room'),
        ],
      ),
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
        : _buildRoomsList();
  }

  Widget _buildJoinRoomTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FaIcon(FontAwesomeIcons.ticket, color: Color(0xFF09090B), size: 20),
              const SizedBox(width: 12),
              Text(
                'Join with Invite Code',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF09090B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the 6-character invite code shared by your friend',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF71717A),
            ),
          ),
          const SizedBox(height: 24),
          
          _buildJoinRoomForm(),
        ],
      ),
    );
  }

  Widget _buildEmptyRoomsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE4E4E7)),
              ),
              child: const FaIcon(
                FontAwesomeIcons.userGroup,
                size: 32,
                color: Color(0xFF71717A),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No rooms yet',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF09090B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first collaboration room\nto start working together with others',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF71717A),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildSmallButton(
              onPressed: _showCreateRoomDialog,
              icon: FontAwesomeIcons.plus,
              text: 'Create First Room',
            ),
          ],
        ),
      ),
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E4E7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _joinRoom(room),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Room Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE4E4E7)),
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.users,
                    size: 18,
                    color: Color(0xFF71717A),
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
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF09090B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.ticket,
                            size: 12,
                            color: const Color(0xFF71717A),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            room.inviteCode,
                            style: GoogleFonts.robotoMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF71717A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FaIcon(
                            FontAwesomeIcons.userGroup,
                            size: 12,
                            color: const Color(0xFF71717A),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${room.memberCount} members',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF71717A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Arrow
                const FaIcon(
                  FontAwesomeIcons.chevronRight,
                  size: 14,
                  color: Color(0xFF71717A),
                ),
              ],
            ),
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
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE4E4E7)),
          ),
          child: TextField(
            controller: _inviteCodeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: GoogleFonts.robotoMono(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF09090B),
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              hintText: 'ABC123',
              hintStyle: GoogleFonts.robotoMono(
                fontSize: 16,
                color: const Color(0xFF71717A),
                letterSpacing: 2,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              counterText: '',
              prefixIcon: const Padding(
                padding: EdgeInsets.all(16),
                child: FaIcon(
                  FontAwesomeIcons.ticket,
                  size: 18,
                  color: Color(0xFF71717A),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
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
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isPrimary ? const Color(0xFF09090B) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isPrimary ? null : Border.all(color: const Color(0xFFE4E4E7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                icon,
                size: 14,
                color: isPrimary ? Colors.white : const Color(0xFF09090B),
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isPrimary ? Colors.white : const Color(0xFF09090B),
                ),
              ),
            ],
          ),
        ),
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
          });
          Navigator.push(
            context,
            MaterialPageRoute(
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

// Create Room Dialog
class CreateRoomDialog extends StatefulWidget {
  final Function(CollaborationRoom) onRoomCreated;

  const CreateRoomDialog({super.key, required this.onRoomCreated});

  @override
  State<CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<CreateRoomDialog> {
  final _formKey = GlobalKey<FormState>();
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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const FaIcon(FontAwesomeIcons.plus, color: Color(0xFF09090B), size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Create Room',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF09090B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Room Name
              Text(
                'Room Name',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF09090B),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g., Project Planning',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF71717A)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF09090B)),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a room name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                'Description (Optional)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF09090B),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'What will you be working on together?',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF71717A)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF09090B)),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 24),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isCreating ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFE4E4E7)),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF09090B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createRoom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF09090B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Create',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create room: ${e.toString()}'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      setState(() => _isCreating = false);
    }
  }
}