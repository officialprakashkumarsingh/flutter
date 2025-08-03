import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
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
      backgroundColor: const Color(0xFFF2F2F7), // iOS systemGroupedBackground
      body: SafeArea(
        child: Column(
          children: [
            _buildIOSHeader(),
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
    );
  }

  Widget _buildIOSHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context).withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Top Row
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    CupertinoIcons.back,
                    size: 20,
                    color: CupertinoColors.systemBlue.resolveFrom(context),
                  ),
                ),
              ),
              const Spacer(),
              if (_tabController.index == 0)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showCreateRoomDialog();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue.resolveFrom(context),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      CupertinoIcons.add,
                      size: 20,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Title Section
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collaborate',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: CupertinoColors.label.resolveFrom(context),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Connect with friends, family & teams',
                    style: TextStyle(
                      fontSize: 15,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // iOS-style Segmented Control
          Container(
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(10),
            ),
            child: CupertinoSlidingSegmentedControl<int>(
              backgroundColor: CupertinoColors.systemGrey6,
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildMyRoomsTab(),
          _buildJoinRoomTab(),
        ],
      ),
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
                  hintStyle: GoogleFonts.inter(color: CupertinoColors.placeholderText),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: CupertinoColors.systemBlue, width: 2),
                  ),
                  filled: true,
                  fillColor: CupertinoColors.systemGrey6,
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
                  hintStyle: GoogleFonts.inter(color: CupertinoColors.placeholderText),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: CupertinoColors.systemBlue, width: 2),
                  ),
                  filled: true,
                  fillColor: CupertinoColors.systemGrey6,
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
                          side: BorderSide.none,
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