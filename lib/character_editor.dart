import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'character_models.dart';
import 'character_service.dart';

class CharacterEditor extends StatefulWidget {
  final Character? character;
  
  const CharacterEditor({super.key, this.character});

  @override
  State<CharacterEditor> createState() => _CharacterEditorState();
}

class _CharacterEditorState extends State<CharacterEditor> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  final _customTagController = TextEditingController();
  
  final CharacterService _characterService = CharacterService();
  bool _isLoading = false;

  // Predefined avatar URLs for quick selection
  final List<String> _avatarOptions = [
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1494790108755-2616b612b47c?w=150&h=150&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=150&h=150&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1531891437562-4301cf35b7e4?w=150&h=150&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1557804506-669a67965ba0?w=150&h=150&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1573497019940-1c28c88b4f3e?w=150&h=150&fit=crop&crop=face',
    'https://images.unsplash.com/photo-1566492031773-4f4e44671d66?w=150&h=150&fit=crop&crop=face',
  ];

  // Template prompts for quick start
  final List<Map<String, String>> _promptTemplates = [
    {
      'name': 'Helpful Assistant',
      'prompt': 'You are a helpful, knowledgeable, and friendly AI assistant. You provide clear, accurate, and useful information while maintaining a warm and approachable tone. You ask clarifying questions when needed and always try to be as helpful as possible.',
    },
    {
      'name': 'Creative Writer',
      'prompt': 'You are a creative and imaginative writer with a flair for storytelling. You excel at crafting engaging narratives, developing interesting characters, and creating vivid descriptions. You inspire creativity and help others develop their writing skills.',
    },
    {
      'name': 'Tech Expert',
      'prompt': 'You are a knowledgeable technology expert with deep understanding of programming, software development, and emerging technologies. You explain complex technical concepts in simple terms and provide practical coding advice and solutions.',
    },
    {
      'name': 'Life Coach',
      'prompt': 'You are a motivational life coach who helps people achieve their goals and overcome challenges. You provide encouraging advice, practical strategies, and help people develop a positive mindset. You listen empathetically and guide others toward personal growth.',
    },
    {
      'name': 'Teacher',
      'prompt': 'You are a patient and experienced teacher who loves helping others learn. You break down complex topics into easy-to-understand explanations, provide examples, and encourage questions. You adapt your teaching style to help each student succeed.',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.character != null) {
      _loadCharacterData();
    } else {
      // Set default avatar for new characters
      _avatarUrlController.text = _avatarOptions.first;
    }
  }

  void _loadCharacterData() {
    final character = widget.character!;
    _nameController.text = character.name;
    _descriptionController.text = character.description;
    _systemPromptController.text = character.systemPrompt;
    _avatarUrlController.text = character.avatarUrl;
    _customTagController.text = character.customTag ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _systemPromptController.dispose();
    _avatarUrlController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  void _selectAvatar(String avatarUrl) {
    setState(() {
      _avatarUrlController.text = avatarUrl;
    });
  }

  void _selectPromptTemplate(String prompt) {
    setState(() {
      _systemPromptController.text = prompt;
    });
  }

  void _showPromptTemplates() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFFF7F7F7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Choose a Prompt Template',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _promptTemplates.length,
                itemBuilder: (context, index) {
                  final template = _promptTemplates[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(
                        template['name']!,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          template['prompt']!,
                          style: GoogleFonts.poppins(fontSize: 12),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _selectPromptTemplate(template['prompt']!);
                      },
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

  Future<void> _saveCharacter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final character = Character(
        id: widget.character?.id ?? _characterService.generateId(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        systemPrompt: _systemPromptController.text.trim(),
        avatarUrl: _avatarUrlController.text.trim(),
        isBuiltIn: widget.character?.isBuiltIn ?? false,
        createdAt: widget.character?.createdAt ?? DateTime.now(),
        customTag: _customTagController.text.trim().isEmpty 
          ? null 
          : _customTagController.text.trim(),
        backgroundColor: null,
      );

      if (widget.character != null) {
        await _characterService.updateCharacter(character);
      } else {
        await _characterService.addCharacter(character);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.character != null 
                ? 'Character updated successfully!' 
                : 'Character created successfully!',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving character: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.character != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Character' : 'Create Character',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF7F7F7),
        elevation: 0,
        actions: [
          if (isEditing && !widget.character!.isBuiltIn)
            IconButton(
              onPressed: () => _showPromptTemplates(),
              icon: const Icon(Icons.lightbulb_outline),
              tooltip: 'Prompt Templates',
            ),
          TextButton(
            onPressed: _isLoading ? null : _saveCharacter,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade600,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Section
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _showAvatarSelection(),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue.shade200, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: _avatarUrlController.text.isNotEmpty
                              ? NetworkImage(_avatarUrlController.text)
                              : null,
                          child: _avatarUrlController.text.isEmpty
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _showAvatarSelection,
                      icon: const Icon(Icons.edit),
                      label: Text(
                        'Change Avatar',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Name Field
              _buildSectionTitle('Character Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: _buildInputDecoration('Enter character name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a character name';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Description Field
              _buildSectionTitle('Description'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: _buildInputDecoration('Brief description of the character'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Custom Tag Field
              _buildSectionTitle('Custom Tag (Optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _customTagController,
                decoration: _buildInputDecoration('Add a custom tag (e.g., "Assistant", "Friend", "Expert")'),
                maxLength: 15,
              ),
              
              const SizedBox(height: 24),
              
              
              // System Prompt Field
              Row(
                children: [
                  Expanded(child: _buildSectionTitle('System Prompt')),
                  TextButton.icon(
                    onPressed: _showPromptTemplates,
                    icon: const Icon(Icons.lightbulb_outline, size: 16),
                    label: Text(
                      'Templates',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _systemPromptController,
                maxLines: 8,
                decoration: _buildInputDecoration(
                  'Define how the character should behave, respond, and interact...',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a system prompt';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Avatar URL Field (Advanced)
              ExpansionTile(
                title: Text(
                  'Advanced Settings',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Avatar URL'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _avatarUrlController,
                          decoration: _buildInputDecoration('https://example.com/avatar.jpg'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter an avatar URL';
                            }
                            if (!Uri.tryParse(value)!.hasAbsolutePath) {
                              return 'Please enter a valid URL';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 100), // Extra space for floating button
            ],
          ),
        ),
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveCharacter,
        icon: _isLoading 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.save),
        label: Text(
          isEditing ? 'Update Character' : 'Create Character',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.all(16),
    );
  }


  void _showAvatarSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: Color(0xFFF7F7F7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Choose an Avatar',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _avatarOptions.length,
                itemBuilder: (context, index) {
                  final avatarUrl = _avatarOptions[index];
                  final isSelected = _avatarUrlController.text == avatarUrl;
                  
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _selectAvatar(avatarUrl);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isSelected 
                            ? Border.all(color: Colors.blue, width: 3)
                            : Border.all(color: Colors.grey.shade300),
                      ),
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(avatarUrl),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}