import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_player_frontend/core/providers/abstract/abstract_app_state_provider.dart';
import 'package:music_player_frontend/core/ui/components/widgets/search_header.dart';
import 'package:music_player_frontend/local_libs/fluenticons/fluenticons.dart';
import 'package:provider/provider.dart';

class _FakeAppStateProvider implements AbstractAppStateProvider {
  @override
  final ValueNotifier<bool> shouldDisplayLocalOnly = ValueNotifier(false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap({
  required _FakeAppStateProvider appStateProvider,
  required SearchHeader child,
}) {
  return Provider<AbstractAppStateProvider>.value(
    value: appStateProvider,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

SearchHeader _buildHeader({
  required void Function(String) onQuery,
  required void Function(String) onSortField,
  required void Function(bool) onAscending,
  required void Function(bool) onLocalOnly,
}) {
  return SearchHeader(
    title: 'Tracks',
    sortFields: const {'Title': null, 'Year': null},
    initialSortField: 'Title',
    initialAscending: true,
    initialLocalOnly: false,
    onQuery: onQuery,
    onSortField: onSortField,
    onAscending: onAscending,
    onLocalOnly: onLocalOnly,
  );
}

void main() {
  Provider.debugCheckInvalidValueType = null;

  group('SearchHeader UI', () {
    testWidgets('debounces search text changes', (tester) async {
      final appStateProvider = _FakeAppStateProvider();
      final queries = <String>[];

      await tester.pumpWidget(
        _wrap(
          appStateProvider: appStateProvider,
          child: _buildHeader(
            onQuery: queries.add,
            onSortField: (_) {},
            onAscending: (_) {},
            onLocalOnly: (_) {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'blue');
      await tester.pump(const Duration(milliseconds: 499));

      expect(queries, isEmpty);

      await tester.pump(const Duration(milliseconds: 2));

      expect(queries, ['blue']);
    });

    testWidgets('emits filter and sort menu selections', (tester) async {
      final appStateProvider = _FakeAppStateProvider();
      final localOnlySelections = <bool>[];
      final sortSelections = <String>[];
      final ascendingSelections = <bool>[];

      await tester.pumpWidget(
        _wrap(
          appStateProvider: appStateProvider,
          child: _buildHeader(
            onQuery: (_) {},
            onSortField: sortSelections.add,
            onAscending: ascendingSelections.add,
            onLocalOnly: localOnlySelections.add,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Local Only'));
      await tester.pumpAndSettle();

      expect(localOnlySelections, [true]);

      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Year').last);
      await tester.pumpAndSettle();

      expect(sortSelections, ['Year']);

      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ascending').last);
      await tester.pumpAndSettle();

      expect(ascendingSelections, [false]);
      expect(find.byIcon(FluentIcons.sortDescending), findsOneWidget);
    });
  });
}
