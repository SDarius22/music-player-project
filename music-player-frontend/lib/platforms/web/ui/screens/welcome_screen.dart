import 'package:flutter/material.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/ui/screens/login_register_screen.dart';
import 'package:music_player_frontend/core/ui/screens/welcome_screen.dart';
import 'package:music_player_frontend/platforms/web/ui/components/widgets/web_top_bar_widget.dart';
import 'package:music_player_frontend/platforms/web/ui/screens/login_register_screen.dart';
import 'package:provider/provider.dart';

class WelcomeScreen extends AbstractWelcomeScreen {
  static Route<dynamic> route() {
    return MaterialPageRoute(builder: (_) => const WelcomeScreen());
  }

  const WelcomeScreen({super.key});

  @override
  AbstractWelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends AbstractWelcomeScreenState<WelcomeScreen> {
  @override
  PreferredSizeWidget buildAppBar(BuildContext context) {
    return const WebAppBarWidget();
  }

  @override
  EdgeInsetsGeometry buildPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: MediaQuery.of(context).size.height * 0.015,
      vertical: MediaQuery.of(context).size.height * 0.015,
    );
  }

  @override
  Widget buildBody(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    double boldSize = height * 0.035;
    return Consumer<AbstractAppStateProvider>(
      builder: (context, appState, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Welcome to Music Player!",
              style: TextStyle(
                fontSize: boldSize,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: height * 0.025),
            Container(
              width: width * 0.9,
              height: height * 0.5,
              alignment: Alignment.center,
              child: WebLoginRegisterScreen(mode: AuthMode.login),
            ),
          ],
        );
      },
    );
  }
}
