import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pos_system/widgets/error_boundary.dart';

class _ReportsFrameworkError extends StatelessWidget {
  const _ReportsFrameworkError();

  @override
  Widget build(BuildContext context) {
    FlutterError.onError?.call(
      FlutterErrorDetails(
        exception: StateError('original framework failure'),
        library: 'test widgets',
      ),
    );
    return const SizedBox.shrink();
  }
}

class _ReportsRecoverableKeyboardError extends StatelessWidget {
  const _ReportsRecoverableKeyboardError();

  @override
  Widget build(BuildContext context) {
    FlutterError.onError?.call(
      FlutterErrorDetails(
        exception: AssertionError(
          'A KeyDownEvent is dispatched, but the state shows that the physical key is already pressed.',
        ),
        library: 'services library',
      ),
    );
    return const MaterialApp(home: Text('POS remains available'));
  }
}

void main() {
  testWidgets(
    'defers fallback update and retains the original framework error',
    (tester) async {
      final originalHandler = FlutterError.onError;
      FlutterError.onError = (_) {};
      addTearDown(() => FlutterError.onError = originalHandler);

      // Match production: ErrorBoundary is above MaterialApp and must provide
      // all root-level Material dependencies when it renders its fallback.
      await tester.pumpWidget(
        const ErrorBoundary(child: _ReportsFrameworkError()),
      );

      // The handler must not call setState while the child is building.
      expect(tester.takeException(), isNull);
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.textContaining('original framework failure'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('recoverable keyboard assertions do not replace the app', (
    tester,
  ) async {
    final originalHandler = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = originalHandler);

    await tester.pumpWidget(
      const ErrorBoundary(child: _ReportsRecoverableKeyboardError()),
    );
    await tester.pump();

    expect(find.text('POS remains available'), findsOneWidget);
    expect(find.text('Something went wrong'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
