import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/user_provider.dart';
import 'package:music_player_frontend/core/ui/screens/loading_screen.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:provider/provider.dart';

import 'abstract/route_builder.dart';

class LoginScreen extends StatefulWidget {
  static Route<void> route() {
    return buildFadeRoute(
      (context, animation, secondaryAnimation) => LoginScreen(),
      settings: RouteSettings(name: "/login"),
    );
  }

  final VoidCallback? onAuthenticatedCallback;

  const LoginScreen({super.key, this.onAuthenticatedCallback});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final codeController = TextEditingController();

  final emailFocus = FocusNode();
  final codeFocus = FocusNode();

  late ValueNotifier<bool> isCodeStep;
  late ValueNotifier<bool> isBusy;

  String get primaryActionLabel => 'Login';

  String get _toggleLabel =>
      'Don\'t have an account yet? Don\'t worry, just enter your email and we\'ll create one for you!';

  @override
  void initState() {
    super.initState();
    isCodeStep = ValueNotifier<bool>(false);
    isBusy = ValueNotifier<bool>(false);
  }

  @override
  void dispose() {
    emailController.dispose();
    codeController.dispose();
    emailFocus.dispose();
    codeFocus.dispose();
    isCodeStep.dispose();
    isBusy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: Container(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.1,
        ),
        alignment: Alignment.center,
        child: buildBody(context),
      ),
    );
  }

  void showToast(String message, {int durationSeconds = 2}) {
    BotToast.showText(
      text: message,
      duration: Duration(seconds: durationSeconds),
    );
  }

  Widget buildHeader(BuildContext context) {
    final title = 'Welcome to MP33r!';
    final subtitle = 'Please continue using your email';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Future<bool> sendEmailCode(String email) {
    final userProvider = context.read<UserProvider>();
    return userProvider.sendLoginCode(email);
  }

  void onAuthenticated(BuildContext context) {
    if (widget.onAuthenticatedCallback != null) {
      widget.onAuthenticatedCallback!();
    } else {
      Navigator.of(context).pushReplacement(LoadingScreen.route());
    }
  }

  Future<void> handleContinue() async {
    if (isBusy.value) return;

    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showToast('Please enter a valid email');
      return;
    }

    isBusy.value = true;
    try {
      final ok = await sendEmailCode(email);
      if (!ok) {
        showToast('Failed to send code');
        return;
      }
      if (!mounted) return;
      context.read<UserProvider>().setPendingEmail(email);
      isCodeStep.value = true;
      FocusScope.of(context).requestFocus(codeFocus);
      showToast('Verification code sent');
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> handleVerify() async {
    if (isBusy.value) return;

    final email = emailController.text.trim();
    final code = codeController.text.trim();

    if (email.isEmpty) {
      showToast('Please enter your email');
      return;
    }
    if (code.length != 6) {
      showToast('Please enter the 6-digit code');
      return;
    }

    isBusy.value = true;
    try {
      final ok = await context.read<UserProvider>().verifyEmailCode(
        email: email,
        code: code,
      );

      if (!ok) {
        showToast('Invalid code');
        return;
      }
      if (!mounted) return;
      showToast('$primaryActionLabel successful');
      onAuthenticated(context);
    } finally {
      isBusy.value = false;
    }
  }

  Widget buildBody(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isCodeStep,
      builder: (context, codeStep, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: isBusy,
          builder: (context, busy, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                buildHeader(context),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  focusNode: emailFocus,
                  enabled: !busy && !codeStep,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email'),
                  onSubmitted: (_) => handleContinue(),
                ),
                const SizedBox(height: 12),
                if (codeStep) ...[
                  TextField(
                    controller: codeController,
                    focusNode: codeFocus,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: '6-digit code',
                    ),
                    onSubmitted: (_) => handleVerify(),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed:
                      busy ? null : (codeStep ? handleVerify : handleContinue),
                  child: Text(codeStep ? 'Verify' : 'Continue'),
                ),
                Text(_toggleLabel, style: const TextStyle(color: Colors.white)),
                if (codeStep) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed:
                        busy
                            ? null
                            : () {
                              codeController.clear();
                              isCodeStep.value = false;
                              FocusScope.of(context).requestFocus(emailFocus);
                            },
                    child: const Text('Change email'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
