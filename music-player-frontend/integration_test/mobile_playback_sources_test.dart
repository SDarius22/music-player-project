import 'package:integration_test/integration_test.dart';
import '../test/integration/mobile_playback_sources_test.dart' as flows;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  flows.main();
}
