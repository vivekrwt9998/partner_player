import 'package:app/models/game_definition.dart';
import 'package:app/screens/games/tetra_tower/tetra_tower_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for AGENTS.md §8 and Tetra Tower's `fixedPortrait`
/// composition.
///
/// Like Tic Tac Toe and Checkers, the current floor is a square 4x4 grid,
/// so it reads the same whether the physical device is portrait or
/// landscape: this screen never needs a software pixel rotation trick, it
/// only ever aspect-fits the same composition to whatever space it is given.
void main() {
  Future<void> pumpScreen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: TetraTowerScreen(mode: GameMode.local)),
    );
    await tester.pumpAndSettle();
  }

  Rect gridScreenRect(WidgetTester tester) {
    return tester.getRect(find.byKey(const ValueKey('tetra_tower_grid')));
  }

  testWidgets(
      'opening and leaving Tetra Tower never calls setPreferredOrientations',
      (WidgetTester tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    // Landscape device: the case most likely to tempt a game-level rotation
    // for a "portrait" game.
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TetraTowerScreen(mode: GameMode.local),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(TetraTowerScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(TetraTowerScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(TetraTowerScreen), findsNothing);

    final orientationCalls = calls
        .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
        .toList();
    expect(
      orientationCalls,
      isEmpty,
      reason: 'Tetra Tower must not force a physical device rotation; a '
          'square grid never needs one.',
    );
  });

  group('the square grid fits the screen regardless of device orientation', () {
    testWidgets('portrait phone', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(390, 844));

      expect(tester.takeException(), isNull);
      final rect = gridScreenRect(tester);
      expect(rect.width, closeTo(rect.height, 0.5));
      expect(rect.right, lessThanOrEqualTo(390.5));
      expect(rect.bottom, lessThanOrEqualTo(844.5));
    });

    testWidgets('landscape phone', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(844, 390));

      expect(tester.takeException(), isNull);
      final rect = gridScreenRect(tester);
      expect(rect.width, closeTo(rect.height, 0.5));
      expect(rect.right, lessThanOrEqualTo(844.5));
      expect(rect.bottom, lessThanOrEqualTo(390.5));
    });

    testWidgets('large tablet landscape', (WidgetTester tester) async {
      await pumpScreen(tester, const Size(1280, 720));

      expect(tester.takeException(), isNull);
      final rect = gridScreenRect(tester);
      expect(rect.width, closeTo(rect.height, 0.5));
    });
  });

  testWidgets(
      'rotating the device live keeps the grid square, with no restart',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: TetraTowerScreen(mode: GameMode.local)),
    );
    await tester.pumpAndSettle();

    final portraitRect = gridScreenRect(tester);
    expect(portraitRect.width, closeTo(portraitRect.height, 0.5));

    // The user physically turns the phone sideways.
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();

    final landscapeRect = gridScreenRect(tester);
    expect(landscapeRect.width, closeTo(landscapeRect.height, 0.5));
    expect(tester.takeException(), isNull);
  });
}
