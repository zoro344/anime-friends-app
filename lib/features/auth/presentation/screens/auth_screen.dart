import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import '../../../../app/app_typography.dart';
import '../../../../core/state/app_state_scope.dart';
import '../../../../core/widgets/af_button.dart';
import '../../../../core/widgets/af_card.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = AppStateScope.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email and password.')),
      );
      return;
    }

    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }

    if (_isSignUp) {
      final username = _usernameController.text.trim().toLowerCase();

      if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(username)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Username must be 3–24 characters: lowercase letters, numbers or underscores.',
            ),
          ),
        );
        return;
      }

      if (_displayNameController.text.trim().length > 40) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Display name cannot exceed 40 characters.'),
          ),
        );
        return;
      }

      await state.signUp(
        email,
        password,
        username,
        _displayNameController.text,
      );
    } else {
      await state.signIn(email, password);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailPattern.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }

    await AppStateScope.of(context).sendPasswordReset(email);
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    if (state.needsProfileRecovery) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Restore your account',
                      textAlign: TextAlign.center,
                      style: AppTypography.headingLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      state.authError.isNotEmpty
                          ? state.authError
                          : 'Your account session is active, but your profile is unavailable.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AFButton(
                      label: state.isBusy ? 'Retrying...' : 'Retry',
                      expanded: true,
                      onPressed: state.isBusy
                          ? null
                          : state.retryProfileRecovery,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: state.isBusy ? null : state.signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text(
                          'AF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Anime Friends',
                    textAlign: TextAlign.center,
                    style: AppTypography.headingLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your anime community starts here.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  AFCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isSignUp ? 'Create account' : 'Welcome back',
                          style: AppTypography.headingSmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isSignUp) ...[
                          TextField(
                            controller: _usernameController,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.none,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                            decoration: _decoration(
                              'Username',
                              Icons.person_outline,
                            ).copyWith(
                              helperText:
                                  '3–24 letters, numbers or underscores',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _displayNameController,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                            decoration: _decoration(
                              'Display name (optional)',
                              Icons.badge_outlined,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          textCapitalization: TextCapitalization.none,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          decoration: _decoration(
                            'Email address',
                            Icons.email_outlined,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _showPassword = !_showPassword;
                                });
                              },
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                        ),
                        if (!_isSignUp)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: state.isBusy ? null : _resetPassword,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                        if (state.authError.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            state.authError,
                            style: const TextStyle(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                        if (state.authMessage.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            state.authMessage,
                            style: const TextStyle(color: Colors.green),
                          ),
                        ],
                        const SizedBox(height: 18),
                        AFButton(
                          label: _isSignUp ? 'Create account' : 'Sign in',
                          expanded: true,
                          onPressed: state.isBusy ? null : _submit,
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: state.isBusy
                              ? null
                              : () {
                                  setState(() {
                                    _isSignUp = !_isSignUp;
                                  });
                                  state.authError = '';
                                  state.authMessage = '';
                                },
                          child: Text(
                            _isSignUp
                                ? 'Already have an account? Sign in'
                                : 'New here? Create an account',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Your password is managed securely by Supabase. '
                    'Your email address is not shown publicly.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
