import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_auth_service.dart';

// Custom shadcn-inspired Input component
class ShadcnInput extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const ShadcnInput({
    super.key,
    required this.controller,
    required this.placeholder,
    this.obscureText = false,
    this.keyboardType,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xFF09090B),
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF71717A),
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE4E4E7), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE4E4E7), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF09090B), width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

// Custom shadcn-inspired Button component
class ShadcnButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ShadcnButtonVariant variant;
  final bool isLoading;

  const ShadcnButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = ShadcnButtonVariant.primary,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: variant == ShadcnButtonVariant.primary 
              ? const Color(0xFF09090B) 
              : variant == ShadcnButtonVariant.ghost
                  ? Colors.transparent
                  : const Color(0xFFF4F4F5),
          foregroundColor: variant == ShadcnButtonVariant.primary 
              ? const Color(0xFFFAFAFA)
              : const Color(0xFF09090B),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: variant == ShadcnButtonVariant.ghost 
                ? const BorderSide(color: Color(0xFFE4E4E7), width: 1)
                : BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFAFAFA)),
                ),
              )
            : child,
      ),
    );
  }
}

// Button variants enum
enum ShadcnButtonVariant { primary, secondary, ghost }

// Custom rounded SnackBar utility
void showRoundedSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: GoogleFonts.inter(
          color: const Color(0xFF09090B),
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      backgroundColor: isError ? const Color(0xFFFEE2E2) : const Color(0xFFF0FDF4),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: isError ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.only(
        bottom: 120,
        left: 16,
        right: 16,
      ),
      duration: const Duration(seconds: 3),
      elevation: 0,
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
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white, // Solid white background
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: showLoginPage 
                          ? LoginPage(onToggle: togglePage)
                          : SignUpPage(onToggle: togglePage),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Logo and Title
        Column(
          children: [
            Text(
              'AhamAI',
              style: GoogleFonts.spaceMono(
                fontSize: 36,
                color: const Color(0xFF09090B),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to continue',
              style: GoogleFonts.inter(
                fontSize: 18,
                color: const Color(0xFF09090B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Welcome back to AhamAI',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF71717A),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // Login Form
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Email Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF09090B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ShadcnInput(
                    controller: _emailController,
                    placeholder: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      size: 18,
                      color: Color(0xFF71717A),
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
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Password Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Password',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF09090B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ShadcnInput(
                    controller: _passwordController,
                    placeholder: 'Enter your password',
                    obscureText: _obscurePassword,
                    enabled: !_isLoading,
                    prefixIcon: const Icon(
                      Icons.lock_outlined,
                      size: 18,
                      color: Color(0xFF71717A),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18,
                        color: const Color(0xFF71717A),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                ],
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
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF09090B),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Sign In Button
              ShadcnButton(
                onPressed: _signIn,
                isLoading: _isLoading,
                child: Text(
                  'Sign In',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Toggle to Sign Up
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF71717A),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onToggle,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Sign Up',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF09090B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
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
        await SupabaseAuthService.createUserProfile(
          userId: response.user!.id,
          email: _emailController.text.trim(),
          fullName: _fullNameController.text.trim(),
        );

        if (mounted) {
          showRoundedSnackBar(context, '✅ Account created! Please check your email to verify.');
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Logo and Title
        Column(
          children: [
            Text(
              'AhamAI',
              style: GoogleFonts.spaceMono(
                fontSize: 36,
                color: const Color(0xFF09090B),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create Account',
              style: GoogleFonts.inter(
                fontSize: 18,
                color: const Color(0xFF09090B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Join AhamAI today',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF71717A),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // Sign Up Form
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Full Name Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Full Name',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF09090B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ShadcnInput(
                    controller: _fullNameController,
                    placeholder: 'Enter your full name',
                    enabled: !_isLoading,
                    prefixIcon: const Icon(
                      Icons.person_outlined,
                      size: 18,
                      color: Color(0xFF71717A),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Email Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF09090B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ShadcnInput(
                    controller: _emailController,
                    placeholder: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      size: 18,
                      color: Color(0xFF71717A),
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
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Password Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Password',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF09090B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ShadcnInput(
                    controller: _passwordController,
                    placeholder: 'Enter your password',
                    obscureText: _obscurePassword,
                    enabled: !_isLoading,
                    prefixIcon: const Icon(
                      Icons.lock_outlined,
                      size: 18,
                      color: Color(0xFF71717A),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18,
                        color: const Color(0xFF71717A),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Confirm Password Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirm Password',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF09090B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ShadcnInput(
                    controller: _confirmPasswordController,
                    placeholder: 'Confirm your password',
                    obscureText: _obscureConfirmPassword,
                    enabled: !_isLoading,
                    prefixIcon: const Icon(
                      Icons.lock_outlined,
                      size: 18,
                      color: Color(0xFF71717A),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18,
                        color: const Color(0xFF71717A),
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
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Sign Up Button
              ShadcnButton(
                onPressed: _signUp,
                isLoading: _isLoading,
                child: Text(
                  'Create Account',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Toggle to Sign In
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account? ",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF71717A),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onToggle,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Sign In',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF09090B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Profile page remains the same but with updated styling
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _fullName;
  String? _email;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final user = SupabaseAuthService.currentUser;
      if (user != null) {
        final profile = await SupabaseAuthService.getUserProfile(user.id);
        if (mounted && profile != null) {
          setState(() {
            _fullName = profile['full_name'];
            _email = profile['email'];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        showRoundedSnackBar(context, 'Error loading profile: ${SupabaseAuthService.getErrorMessage(e)}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    
    try {
      await SupabaseAuthService.signOut();
      if (mounted) {
        showRoundedSnackBar(context, '✅ Signed out successfully');
      }
    } catch (e) {
      if (mounted) {
        showRoundedSnackBar(context, 'Error signing out: ${SupabaseAuthService.getErrorMessage(e)}', isError: true);
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
            
            // Profile Header
            Text(
              'Profile',
              style: GoogleFonts.spaceMono(
                fontSize: 32,
                color: const Color(0xFF09090B),
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 32),
            
            if (_isLoading)
              const CircularProgressIndicator(color: Color(0xFF09090B))
            else ...[
              // Profile Info
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full Name',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF71717A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _fullName ?? 'Not available',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: const Color(0xFF09090B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Text(
                        'Email',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF71717A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _email ?? 'Not available',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: const Color(0xFF09090B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Sign Out Button
              ShadcnButton(
                onPressed: _signOut,
                isLoading: _isLoading,
                variant: ShadcnButtonVariant.secondary,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.logout,
                      size: 18,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const Spacer(),
          ],
        ),
      ),
    );
  }
}