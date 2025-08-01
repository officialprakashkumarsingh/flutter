import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_auth_service.dart';

// Custom rounded SnackBar utility
void showRoundedSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: GoogleFonts.inter(
          color: const Color(0xFF000000),
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      backgroundColor: isError ? const Color(0xFFFFE5E5) : const Color(0xFFE8F5E8),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isError ? const Color(0xFFFF6B6B) : const Color(0xFF4CAF50),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.only(
        bottom: 120, // Position above input area
        left: 16,
        right: 16,
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

class AuthAndProfilePages extends StatefulWidget {
  const AuthAndProfilePages({super.key});

  @override
  State<AuthAndProfilePages> createState() => _AuthAndProfilePagesState();
}

class _AuthAndProfilePagesState extends State<AuthAndProfilePages> {
  bool showLoginPage = true;

  void togglePage() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFFF4F3F0),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F3F0),
        body: showLoginPage 
            ? LoginPage(onToggle: togglePage)
            : SignUpPage(onToggle: togglePage),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final VoidCallback onToggle;
  
  const LoginPage({super.key, required this.onToggle});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseAuthService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user != null) {
        // User signed in successfully, AuthGate will handle navigation
        if (mounted) {
          showRoundedSnackBar(context, '✅ Welcome back!');
        }
      }
    } catch (e) {
      if (mounted) {
        showRoundedSnackBar(context, '❌ ${SupabaseAuthService.getErrorMessage(e)}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      showRoundedSnackBar(context, 'Please enter your email address first', isError: true);
      return;
    }

    try {
      await SupabaseAuthService.resetPassword(_emailController.text.trim());
      if (mounted) {
        showRoundedSnackBar(context, '✅ Password reset email sent!');
      }
    } catch (e) {
      if (mounted) {
        showRoundedSnackBar(context, '❌ ${SupabaseAuthService.getErrorMessage(e)}', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const Spacer(),
            
            // AhamAI Logo
            Text(
              'AhamAI',
              style: GoogleFonts.spaceMono(
                fontSize: 32,
                color: const Color(0xFF000000),
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Text(
              'Sign in to continue',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF000000),
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 4),
            
            Text(
              'Welcome back to AhamAI',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFFA3A3A3),
                fontWeight: FontWeight.w400,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Login Form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Email Field
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0DED9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC4C4C4)),
                    ),
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF000000),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFFA3A3A3),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Color(0xFFA3A3A3),
                          size: 18,
                        ),
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1.5),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Password Field
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0DED9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC4C4C4)),
                    ),
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_isLoading,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF000000),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFFA3A3A3),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outlined,
                          color: Color(0xFFA3A3A3),
                          size: 18,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFFA3A3A3),
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1.5),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _signIn(),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Forgot Password?',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF666666),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Sign In Button
                  Container(
                    width: double.infinity,
                    height: 40, // Reduced from 44 to 40
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF000000),
                        foregroundColor: const Color(0xFFFFFFFF),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16, // Reduced from 18 to 16
                              height: 16, // Reduced from 18 to 16
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Sign In',
                              style: GoogleFonts.inter(
                                fontSize: 13, // Reduced from 14 to 13
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 28),
            
            // Switch to Sign Up
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'New to AhamAI?',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFA3A3A3),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _isLoading ? null : widget.onToggle,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Sign Up',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF000000),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class SignUpPage extends StatefulWidget {
  final VoidCallback onToggle;
  
  const SignUpPage({super.key, required this.onToggle});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseAuthService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
      );

      if (response.user != null) {
        // Create user profile
        await SupabaseAuthService.createUserProfile(
          userId: response.user!.id,
          email: _emailController.text.trim(),
          fullName: _fullNameController.text.trim(),
        );

        if (mounted) {
          showRoundedSnackBar(context, '✅ Account created! Please check your email to verify.');
          
          // Switch to login page
          widget.onToggle();
        }
      }
    } catch (e) {
      if (mounted) {
        showRoundedSnackBar(context, '❌ ${SupabaseAuthService.getErrorMessage(e)}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const Spacer(),
            
            // AhamAI Logo
            Text(
              'AhamAI',
              style: GoogleFonts.spaceMono(
                fontSize: 32,
                color: const Color(0xFF000000),
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Text(
              'Create Account',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF000000),
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 4),
            
            Text(
              'Join AhamAI today',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFFA3A3A3),
                fontWeight: FontWeight.w400,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Sign Up Form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Full Name Field
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0DED9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC4C4C4)),
                    ),
                    child: TextFormField(
                      controller: _fullNameController,
                      enabled: !_isLoading,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF000000),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Full Name',
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFFA3A3A3),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: const Icon(
                          Icons.person_outlined,
                          color: Color(0xFFA3A3A3),
                          size: 18,
                        ),
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1.5),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Email Field
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0DED9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC4C4C4)),
                    ),
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF000000),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFFA3A3A3),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Color(0xFFA3A3A3),
                          size: 18,
                        ),
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1.5),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Password Field
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0DED9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC4C4C4)),
                    ),
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_isLoading,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF000000),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFFA3A3A3),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outlined,
                          color: Color(0xFFA3A3A3),
                          size: 18,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFFA3A3A3),
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1.5),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Confirm Password Field
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0DED9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC4C4C4)),
                    ),
                    child: TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      enabled: !_isLoading,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF000000),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Confirm Password',
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFFA3A3A3),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outlined,
                          color: Color(0xFFA3A3A3),
                          size: 18,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFFA3A3A3),
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1.5),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _signUp(),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sign Up Button
                  Container(
                    width: double.infinity,
                    height: 40, // Reduced from 44 to 40
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF000000),
                        foregroundColor: const Color(0xFFFFFFFF),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16, // Reduced from 18 to 16
                              height: 16, // Reduced from 18 to 16
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Create Account',
                              style: GoogleFonts.inter(
                                fontSize: 13, // Reduced from 14 to 13
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 28),
            
            // Switch to Login
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account?',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFA3A3A3),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _isLoading ? null : widget.onToggle,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Sign In',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF000000),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            
            const Spacer(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}