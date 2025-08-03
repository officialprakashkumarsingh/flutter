import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F4), // Cream background
      body: CustomPaint(
        painter: HistoryPatternPainter(),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              _buildHeader(),
              
              // Content Area
              Expanded(
                child: _buildHistoryList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Description
          Text(
            'Saved',
            style: GoogleFonts.spaceMono( // Same font as AhamAI
              fontSize: 20, // Bigger
              fontWeight: FontWeight.w600,
              color: const Color(0xFF09090B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your saved conversations',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF71717A),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Search Bar
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _searchController.text.isNotEmpty 
              ? const Color(0xFF09090B) 
              : const Color(0xFFE4E4E7),
          width: _searchController.text.isNotEmpty ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF09090B),
        ),
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          hintStyle: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF71717A),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF71717A),
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Demo history items
          Expanded(
            child: ListView.builder(
              itemCount: _demoHistoryItems.length,
              itemBuilder: (context, index) {
                final item = _demoHistoryItems[index];
                if (_searchQuery.isNotEmpty && 
                    !item.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
                  return const SizedBox.shrink();
                }
                return _buildHistoryItem(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(HistoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E4E7).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: item.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: FaIcon(
              item.icon,
              size: 16,
              color: item.color,
            ),
          ),
        ),
        title: Text(
          item.title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF09090B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF71717A),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          item.time,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF71717A),
          ),
        ),
        onTap: () {
          // Handle history item tap
          HapticFeedback.lightImpact();
        },
      ),
    );
  }

  final List<HistoryItem> _demoHistoryItems = [
    HistoryItem(
      title: 'Flutter Development Help',
      subtitle: 'Asked about state management...',
      time: '2 min ago',
      icon: FontAwesomeIcons.code,
      color: const Color(0xFF059669),
    ),
    HistoryItem(
      title: 'Creative Writing Session',
      subtitle: 'Working on a short story...',
      time: '1 hour ago',
      icon: FontAwesomeIcons.feather,
      color: const Color(0xFFDC2626),
    ),
    HistoryItem(
      title: 'Business Strategy',
      subtitle: 'Discussed marketing plans...',
      time: '3 hours ago',
      icon: FontAwesomeIcons.briefcase,
      color: const Color(0xFF7C2D12),
    ),
    HistoryItem(
      title: 'Learning Session',
      subtitle: 'Studying machine learning...',
      time: 'Yesterday',
      icon: FontAwesomeIcons.graduationCap,
      color: const Color(0xFF2563EB),
    ),
    HistoryItem(
      title: 'General Chat',
      subtitle: 'Random conversation...',
      time: '2 days ago',
      icon: FontAwesomeIcons.comments,
      color: const Color(0xFF7C3AED),
    ),
  ];
}

class HistoryItem {
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final Color color;

  HistoryItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.color,
  });
}

class HistoryPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fill with cream background
    final paint = Paint()..color = const Color(0xFFF9F7F4);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    // Create subtle dot pattern
    final dotPaint = Paint()
      ..color = Colors.grey.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    
    const dotSize = 1.2;
    const spacing = 25.0;
    
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize, dotPaint);
        // Add variation for subtle texture
        if ((x / spacing) % 3 == 0 && (y / spacing) % 3 == 0) {
          canvas.drawCircle(Offset(x + spacing/2, y + spacing/2), dotSize * 0.6, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}