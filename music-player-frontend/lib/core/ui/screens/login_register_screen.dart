import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/user_provider.dart';
import 'package:music_player_frontend/local_libs/custom_scaffold/glass_scaffold.dart';
import 'package:provider/provider.dart';

enum AuthMode { login, register }

abstract class AbstractAuthScreen extends StatefulWidget {
  final AuthMode mode;

  const AbstractAuthScreen({super.key, required this.mode});
}

abstract class AbstractAuthScreenState<T extends AbstractAuthScreen>
    extends State<T> {
  final emailController = TextEditingController();
  final codeController = TextEditingController();

  final emailFocus = FocusNode();
  final codeFocus = FocusNode();

  late ValueNotifier<bool> isCodeStep;
  late ValueNotifier<bool> isBusy;

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

  void showToast(String message, {int durationSeconds = 2}) {
    BotToast.showText(
      text: message,
      duration: Duration(seconds: durationSeconds),
    );
  }

  String get primaryActionLabel =>
      widget.mode == AuthMode.login ? 'Login' : 'Register';

  AuthMode get _otherMode =>
      widget.mode == AuthMode.login ? AuthMode.register : AuthMode.login;

  String get _toggleLabel =>
      widget.mode == AuthMode.login
          ? 'Don\'t have an account yet? Register here'
          : 'Already have an account? Log in';

  Future<bool> sendEmailCode(String email);

  Widget buildHeader(BuildContext context) => const SizedBox.shrink();

  EdgeInsetsGeometry buildPadding(BuildContext context) => EdgeInsets.zero;

  void onAuthenticated(BuildContext context) {
    Navigator.pop(context);
  }

  void onToggleAuthMode(BuildContext context, AuthMode mode) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => buildAuthScreenForMode(mode)),
    );
  }

  AbstractAuthScreen buildAuthScreenForMode(AuthMode mode);

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

      showToast('$primaryActionLabel successful');
      onAuthenticated(context);
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> handleGoogle() async {
    if (isBusy.value) return;

    isBusy.value = true;
    try {
      final ok = await context.read<UserProvider>().loginWithGoogle();
      if (!ok) {
        showToast('Google sign-in not available');
        return;
      }
      showToast('$primaryActionLabel successful');
      onAuthenticated(context);
    } finally {
      isBusy.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: buildAppBar(context),
      body: Padding(padding: buildPadding(context), child: buildBody(context)),
    );
  }

  PreferredSizeWidget buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(primaryActionLabel),
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  Widget buildBody(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isCodeStep,
      builder: (context, codeStep, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: isBusy,
          builder: (context, busy, __) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: busy ? null : handleGoogle,
                  child: Text(
                    '$primaryActionLabel with Google',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed:
                      busy
                          ? null
                          : () {
                            codeController.clear();
                            isCodeStep.value = false;
                            onToggleAuthMode(context, _otherMode);
                          },
                  child: Text(
                    _toggleLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
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
