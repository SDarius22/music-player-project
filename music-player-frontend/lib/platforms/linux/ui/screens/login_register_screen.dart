import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/user_provider.dart';
import 'package:music_player_frontend/core/ui/screens/login_register_screen.dart';
import 'package:provider/provider.dart';

class LinuxLoginRegisterScreen extends AbstractAuthScreen {
  static Route<void> route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return LinuxLoginRegisterScreen(mode: AuthMode.login);
      },
    );
  }

  const LinuxLoginRegisterScreen({super.key, required super.mode});

  @override
  State<LinuxLoginRegisterScreen> createState() =>
      _LinuxLoginRegisterScreenState();
}

class _LinuxLoginRegisterScreenState
    extends AbstractAuthScreenState<LinuxLoginRegisterScreen> {
  @override
  AbstractAuthScreen buildAuthScreenForMode(AuthMode mode) {
    return LinuxLoginRegisterScreen(mode: mode);
  }

  @override
  EdgeInsetsGeometry buildPadding(BuildContext context) {
    return const EdgeInsets.all(24);
  }

  @override
  Widget buildHeader(BuildContext context) {
    final title =
        widget.mode == AuthMode.login ? 'Welcome back' : 'Create account';
    final subtitle =
        widget.mode == AuthMode.login
            ? 'Sign in with Google or verify your email'
            : 'Sign up with Google or verify your email';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  @override
  Future<bool> sendEmailCode(String email) {
    final userProvider = context.read<UserProvider>();

    return userProvider.sendLoginCode(email);
  }

  @override
  void onAuthenticated(BuildContext context) {
    Navigator.of(context).pop(true);
  }
}
