import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'models.dart';

/* ----------------------------------------------------------
   SAVED PAGE - With Swiping between Tabs
---------------------------------------------------------- */
class SavedPage extends StatefulWidget {
  final List<Message> bookmarkedMessages;
  final List<ChatSession> chatHistory;
  final void Function(ChatSession) onLoadChat;

  const SavedPage({
    super.key,
    required this.bookmarkedMessages,
    required this.chatHistory,
    required this.onLoadChat,
  });

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: const Color(0xFFF4F3F0),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE0DED9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC4C4C4)),
            ),
            child: _CustomSegmentedControl(
              selectedIndex: _selectedIndex,
              onChanged: (index) {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: [
                _ChatHistoryView(chatHistory: widget.chatHistory, onLoadChat: widget.onLoadChat),
                _SavedRepliesView(bookmarkedMessages: widget.bookmarkedMessages),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------------------------------------
   CUSTOM SEGMENTED CONTROL
---------------------------------------------------------- */
class _CustomSegmentedControl extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _CustomSegmentedControl({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F3F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            left: selectedIndex == 0 ? 0 : (MediaQuery.of(context).size.width - 48) / 2,
            right: selectedIndex == 1 ? 0 : (MediaQuery.of(context).size.width - 48) / 2,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF000000),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Row(
            children: [
              _buildSegment("History", 0),
              _buildSegment("Saved Replies", 1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(String title, int index) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(index),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              color: isSelected ? const Color(0xFFFFFFFF) : const Color(0xFFA3A3A3),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 15,
              fontFamily: 'Inter',
            ),
            child: Text(title),
          ),
        ),
      ),
    );
  }
}


/* ----------------------------------------------------------
   CHAT HISTORY VIEW
---------------------------------------------------------- */
class _ChatHistoryView extends StatelessWidget {
  final List<ChatSession> chatHistory;
  final void Function(ChatSession) onLoadChat;

  const _ChatHistoryView({required this.chatHistory, required this.onLoadChat});

  @override
  Widget build(BuildContext context) {
    if (chatHistory.isEmpty) {
      return const _EmptyState(
        icon: Icons.history_rounded,
        title: 'No Chat History',
        description: 'Your past chat sessions will appear here. Start a new chat to save your current one.',
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        padding: EdgeInsets.only(
          top: 8,
          bottom: kBottomNavigationBarHeight + 80,
        ),
        itemCount: chatHistory.length,
        itemBuilder: (context, index) {
          final session = chatHistory[index];
          return _ChatHistoryCard(
            session: session,
            onTap: () => onLoadChat(session),
          );
        },
      ),
    );
  }
}

class _ChatHistoryCard extends StatelessWidget {
  final ChatSession session;
  final VoidCallback onTap;

  const _ChatHistoryCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE9E5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC4C4C4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    session.title,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: Color(0xFF000000)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: const Color(0xFFA3A3A3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/* ----------------------------------------------------------
   SAVED REPLIES (BOOKMARKS) VIEW
---------------------------------------------------------- */
class _SavedRepliesView extends StatelessWidget {
  final List<Message> bookmarkedMessages;
  const _SavedRepliesView({required this.bookmarkedMessages});

  @override
  Widget build(BuildContext context) {
    if (bookmarkedMessages.isEmpty) {
      return const _EmptyState(
        icon: Icons.bookmark_outline_rounded,
        title: 'No Saved Replies',
        description: 'Tap the bookmark icon on an AI response in your chat to save it here.',
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        padding: EdgeInsets.only(
          top: 8,
          bottom: kBottomNavigationBarHeight + 80,
        ),
        itemCount: bookmarkedMessages.length,
        itemBuilder: (context, index) {
          final message = bookmarkedMessages[index];
          return _SavedMessageCard(message: message);
        },
      ),
    );
  }
}

class _SavedMessageCard extends StatelessWidget {
  final Message message;
  const _SavedMessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE9E5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC4C4C4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 8, color: const Color(0xFF000000)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 20, color: const Color(0xFF000000)),
                        const SizedBox(width: 8),
                                                  const Text('Saved Reply', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF000000))),
                      ],
                    ),
                                          const Divider(height: 24, color: Color(0xFFC4C4C4)),
                    MarkdownBody(
                      data: message.text,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF000000)),
                        code: const TextStyle(backgroundColor: Color(0xFFEAE9E5), fontFamily: 'monospace', color: Color(0xFF000000)),
                        codeblockDecoration: const BoxDecoration(
                          color: Color(0xFFEAE9E5),
                        ),
                        h1: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
                        h2: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
                        h3: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
                        strong: const TextStyle(color: Color(0xFF000000), fontWeight: FontWeight.bold),
                        em: const TextStyle(color: Color(0xFF000000), fontStyle: FontStyle.italic),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _CardActionButton(
                          icon: Icons.copy_outlined,
                          label: 'Copy',
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: message.text));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(seconds: 2), content: Text('Copied to clipboard')));
                          },
                        ),
                        const SizedBox(width: 8),
                        _CardActionButton(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(seconds: 2), content: Text('Share functionality coming soon!')));
                          },
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CardActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F3F0),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFFA3A3A3)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Color(0xFFA3A3A3))),
            ],
          ),
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------
   GENERIC EMPTY STATE WIDGET
---------------------------------------------------------- */
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _EmptyState({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: const Color(0xFFA3A3A3)),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF000000))),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Color(0xFFA3A3A3), height: 1.4)),
          ],
        ),
      ),
    );
  }
}