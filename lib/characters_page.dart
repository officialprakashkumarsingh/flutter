import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'character_models.dart';
import 'character_service.dart';
import 'character_editor.dart';
import 'character_chat_page.dart';

class CharactersPage extends StatefulWidget {
  final String selectedModel;
  
  const CharactersPage({super.key, required this.selectedModel});

  @override
  State<CharactersPage> createState() => _CharactersPageState();
}

class _CharactersPageState extends State<CharactersPage> with TickerProviderStateMixin {
  final CharacterService _characterService = CharacterService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _searchQuery = '';
  bool _showFavorites = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    
    // Listen to character service changes
    _characterService.addListener(_onCharactersChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _characterService.removeListener(_onCharactersChanged);
    super.dispose();
  }

  void _onCharactersChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<Character> get _filteredCharacters {
    var characters = _characterService.characters;
    
    if (_searchQuery.isNotEmpty) {
      characters = characters.where((char) =>
        char.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        char.description.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    return characters;
  }



  void _createNewCharacter() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CharacterEditor(),
      ),
    );
  }

  void _editCharacter(Character character) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterEditor(character: character),
      ),
    );
  }

  void _chatWithCharacter(Character character) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharacterChatPage(
          character: character,
          selectedModel: widget.selectedModel,
        ),
      ),
    );
  }

  void _deleteCharacter(Character character) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF4F3F0),
        title: const Text('Delete Character', style: TextStyle(color: Color(0xFF000000))),
        content: Text('Are you sure you want to delete "${character.name}"?', style: const TextStyle(color: Color(0xFFA3A3A3))),
        actions: [
                      TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFFA3A3A3))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
        ],
      ),
    );

    if (confirmed == true) {
      await _characterService.deleteCharacter(character.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final characters = _filteredCharacters;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF4F3F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F3F0),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF000000)),
        ),
        title: Text(
          'Characters',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF000000),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _createNewCharacter,
            icon: const Icon(Icons.add_rounded, color: Color(0xFF000000)),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Search bar - Matching main chat input design exactly
            Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24), // Fully rounded like main chat
                border: Border.all(
                  color: const Color(0xFFEAE9E5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(
                  color: Color(0xFF000000),
                  fontSize: 16,
                  height: 1.4,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search characters...',
                  hintStyle: TextStyle(
                    color: Color(0xFFA3A3A3),
                    fontSize: 16,
                    height: 1.4,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Color(0xFFA3A3A3),
                    size: 22,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
            
            // Characters grid
            Expanded(
              child: characters.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.groups_rounded,
                            size: 48,
                            color: const Color(0xFFA3A3A3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty 
                                ? 'No characters found' 
                                : 'No characters yet',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFFA3A3A3),
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: characters.length,
                      itemBuilder: (context, index) {
                        final character = characters[index];
                        return _buildCharacterCard(character);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterCard(Character character) {
    return GestureDetector(
      onTap: () => _chatWithCharacter(character),
      onLongPress: () => _showCharacterOptions(character),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAE9E5), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Avatar - Made larger and more prominent
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF000000),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: character.avatarUrl.isNotEmpty
                      ? Image.network(
                          character.avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              character.name.isNotEmpty ? character.name[0].toUpperCase() : 'C',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            character.name.isNotEmpty ? character.name[0].toUpperCase() : 'C',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Name - Better typography
              Text(
                character.name,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF000000),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 6),
              
              // Description - Improved readability
              Expanded(
                child: Text(
                  character.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFFA3A3A3),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCharacterOptions(Character character) {
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
                leading: const Icon(Icons.edit_rounded, color: Color(0xFF000000)),
                title: Text(
                  'Edit Character',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF000000),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _editCharacter(character);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: Text(
                  'Delete Character',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteCharacter(character);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}