import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'main_shell.dart';
import 'models.dart' as app_models;
import 'auth_service.dart';
import 'file_upload_widget.dart';

/* ----------------------------------------------------------
   AUTH GATE
---------------------------------------------------------- */
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<app_models.User?>(
        valueListenable: AuthService().currentUser,
        builder: (context, user, child) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: user != null ? const MainShell() : const LoginOrSignupPage(),
          );
        },
      ),
    );
  }
}

/* ----------------------------------------------------------
   LOGIN OR SIGNUP PAGE
---------------------------------------------------------- */
class LoginOrSignupPage extends StatefulWidget {
  const LoginOrSignupPage({super.key});

  @override
  State<LoginOrSignupPage> createState() => _LoginOrSignupPageState();
}

class _LoginOrSignupPageState extends State<LoginOrSignupPage> {
  bool _showLoginPage = true;

  void togglePages() {
    setState(() {
      _showLoginPage = !_showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AuthPage(
      key: ValueKey(_showLoginPage), // Ensures state resets on toggle
      showLoginPage: _showLoginPage,
      onToggle: togglePages,
    );
  }
}

/* ----------------------------------------------------------
   AUTH PAGE - Smaller, cleaner design
---------------------------------------------------------- */
class _AuthPage extends StatefulWidget {
  final bool showLoginPage;
  final VoidCallback onToggle;

  const _AuthPage({super.key, required this.showLoginPage, required this.onToggle});

  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<_AuthPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    FocusScope.of(context).unfocus();
    
    setState(() => _isLoading = true);
    String? error;

    if (widget.showLoginPage) {
      error = await AuthService().signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } else {
      if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
        error = "Please fill all fields.";
      } else {
        // Use default avatar for new users
        error = await AuthService().signUp(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          avatarUrl: AuthService().availableAvatars.first,
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F3F0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      
                      // AhamAI Logo - smaller
                      Text(
                        'AhamAI',
                        style: GoogleFonts.spaceMono(
                          fontSize: 36,
                          color: const Color(0xFF000000),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Simple underline - smaller
                      Container(
                        height: 2,
                        width: 50,
                        color: const Color(0xFF000000),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      Text(
                        widget.showLoginPage 
                            ? 'Welcome back' 
                            : 'Create account',
                        style: GoogleFonts.inter(
                          fontSize: 20, 
                          color: const Color(0xFF000000),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      
                      const SizedBox(height: 6),
                      
                      Text(
                        widget.showLoginPage 
                            ? 'Sign in to continue' 
                            : 'Join AhamAI today',
                        style: GoogleFonts.inter(
                          fontSize: 14, 
                          color: const Color(0xFFA3A3A3),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      
                      const SizedBox(height: 32),

                      // Form with animation
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                        child: widget.showLoginPage ? _buildLoginForm() : _buildSignupForm(),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Submit button - smaller
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: _isLoading
                            ? Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAE9E5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFC4C4C4)),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF000000),
                                    ),
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF000000),
                                  foregroundColor: const Color(0xFFFFFFFF),
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  widget.showLoginPage ? 'Sign In' : 'Create Account', 
                                  style: GoogleFonts.inter(
                                    fontSize: 14, 
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                      ),
                      
                      const SizedBox(height: 24),

                      // Toggle between login/signup
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.showLoginPage ? 'New to AhamAI?' : 'Already have an account?',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFA3A3A3),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: widget.onToggle,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              widget.showLoginPage ? 'Create account' : 'Sign in',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600, 
                                color: const Color(0xFF000000),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login'),
      children: [
        _buildTextField(
          controller: _emailController, 
          hintText: 'Email', 
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _passwordController, 
          hintText: 'Password', 
          icon: Icons.lock_outline, 
          obscureText: true,
        ),
      ],
    );
  }

  Widget _buildSignupForm() {
    return Column(
      key: const ValueKey('signup'),
      children: [
        _buildTextField(
          controller: _nameController, 
          hintText: 'Full Name', 
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _emailController, 
          hintText: 'Email', 
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _passwordController, 
          hintText: 'Password', 
          icon: Icons.lock_outline, 
          obscureText: true,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String hintText, 
    required IconData icon, 
    bool obscureText = false,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFE0DED9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC4C4C4)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: GoogleFonts.inter(
          fontSize: 14, 
          fontWeight: FontWeight.w400,
          color: const Color(0xFF000000),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFFA3A3A3),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            icon, 
            color: const Color(0xFFA3A3A3), 
            size: 18,
          ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF000000), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------
   PROFILE PAGE - Updated without avatar selection
---------------------------------------------------------- */
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F3F0),
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF000000),
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF000000)),
        ),
      ),
      body: ValueListenableBuilder<app_models.User?>(
        valueListenable: _auth.currentUser,
        builder: (context, user, _) {
          if (user == null) return const SizedBox();
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                
                // User avatar - simplified
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF000000),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      user.email.isNotEmpty ? user.email[0].toUpperCase() : 'U',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Text(
                  user.name,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF000000),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  user.email,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: const Color(0xFFA3A3A3),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Settings options
                _buildSettingsOption(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () {},
                ),
                
                _buildSettingsOption(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  onTap: () {},
                ),
                
                _buildSettingsOption(
                  icon: Icons.info_outline_rounded,
                  title: 'About',
                  onTap: () {},
                ),
                
                const SizedBox(height: 20),
                
                // Sign out button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _auth.signOut();
                      if (mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Sign Out',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFEAE9E5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF000000), size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF000000),
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFA3A3A3), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}