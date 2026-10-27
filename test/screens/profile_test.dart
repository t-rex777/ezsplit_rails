import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ezsplit_mobile/data/api_client.dart';
import 'package:ezsplit_mobile/data/api_error.dart';
import 'package:ezsplit_mobile/data/categories_repository.dart';
import 'package:ezsplit_mobile/data/models.dart';
import 'package:ezsplit_mobile/state/session.dart';
import 'package:ezsplit_mobile/state/theme_mode.dart';
import 'package:ezsplit_mobile/widgets/brutal_button.dart';
import 'package:ezsplit_mobile/widgets/brutal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

class _CountingAdapter implements HttpClientAdapter {
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    throw StateError('no network call expected: ${options.path}');
  }

  @override
  void close({bool force = false}) {}
}

Future<ProviderContainer> pumpProfile(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakeUsersRepository? users,
  FakeCategoriesRepository? categories,
  ApiClient? client,
  String path = '/profile',
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final usersRepo = users ?? FakeUsersRepository();
  final container = await pumpApp(
    tester,
    auth ?? FakeAuthRepository(current: testUser),
    client: client,
    extraOverrides: [
      ...repoOverrides(FakeGroupsRepository(), usersRepo),
      categoriesRepositoryProvider.overrideWithValue(
        categories ?? FakeCategoriesRepository(),
      ),
    ],
  );
  routerOf(container).go(path);
  await tester.pumpAndSettle();
  return container;
}

Finder _button(String label) => find.widgetWithText(BrutalButton, label);

/// Pills and round buttons, found by the label they give assistive tech.
Finder _surface(String label) => find.byWidgetPredicate(
  (w) => w is BrutalSurface && w.semanticLabel == label,
);

Finder _swatch(String label) => find.byWidgetPredicate(
  (w) =>
      w is Semantics &&
      w.properties.label == label &&
      w.properties.button == true,
);

void main() {
  group('Profile', () {
    testWidgets('shows the name, email and rows', (tester) async {
      await pumpProfile(tester);
      expect(find.text('Neha Kapoor'), findsOneWidget);
      expect(find.text('neha@gmail.com'), findsOneWidget);
      expect(find.text('NK'), findsOneWidget);
      expect(find.text('Edit personal details'), findsOneWidget);
      expect(find.text('My categories'), findsOneWidget);
    });

    testWidgets('tapping Dark switches the app and persists', (tester) async {
      final c = await pumpProfile(tester);
      expect(c.read(themeModeProvider), ThemeMode.system);
      await tester.tap(_surface('Dark'));
      await tester.pumpAndSettle();
      expect(c.read(themeModeProvider), ThemeMode.dark);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);

      // A fresh app with the same stored preferences starts in dark.
      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      expect(fresh.read(themeModeProvider), ThemeMode.system);
      await fresh.read(themeModeProvider.notifier).loaded;
      expect(fresh.read(themeModeProvider), ThemeMode.dark);
    });

    testWidgets('Edit personal details opens the form', (tester) async {
      final c = await pumpProfile(tester);
      await tester.tap(find.text('Edit personal details'));
      await tester.pumpAndSettle();
      expect(locationOf(c), '/profile/details');
    });

    testWidgets('My categories opens the list', (tester) async {
      final c = await pumpProfile(tester);
      await tester.tap(find.text('My categories'));
      await tester.pumpAndSettle();
      expect(locationOf(c), '/profile/categories');
    });

    testWidgets('log out asks first, then ends on the login screen', (
      tester,
    ) async {
      final auth = FakeAuthRepository(current: testUser);
      final c = await pumpProfile(tester, auth: auth);
      await tester.tap(_button('Log out'));
      await tester.pumpAndSettle();
      // Asking does not log out.
      expect(auth.logouts, 0);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(_button('Cancel'));
      await tester.pumpAndSettle();
      expect(auth.logouts, 0);
      expect(locationOf(c), '/profile');

      await tester.tap(_button('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(_button('Log out').last);
      await tester.pumpAndSettle();
      expect(auth.logouts, 1);
      expect(locationOf(c), '/login');
    });

    testWidgets('the confirm button is disabled while logging out', (
      tester,
    ) async {
      final auth = FakeAuthRepository(current: testUser)
        ..logoutGate = Completer<void>();
      await pumpProfile(tester, auth: auth);
      await tester.tap(_button('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(_button('Log out').last);
      await tester.pump();
      expect(auth.logouts, 1);
      // A second tap does nothing and the sheet stays open.
      await tester.tap(_button('Log out').last);
      await tester.pump();
      expect(auth.logouts, 1);
      expect(
        tester.widget<BrutalButton>(_button('Log out').last).onPressed,
        isNull,
      );
      expect(tester.widget<BrutalButton>(_button('Cancel')).onPressed, isNull);
      auth.logoutGate!.complete();
      await tester.pumpAndSettle();
    });
  });

  group('Edit details', () {
    testWidgets('shows the saved details and a read-only email', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        auth: FakeAuthRepository(
          current: const User(
            id: 1,
            firstName: 'Neha',
            lastName: 'Kapoor',
            email: 'neha@gmail.com',
            phone: '9876543210',
            dob: null,
          ),
        ),
        path: '/profile/details',
      );
      expect(find.text('Your details'), findsOneWidget);
      expect(find.text('Neha'), findsOneWidget);
      expect(find.text('Kapoor'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
      expect(find.text('neha@gmail.com'), findsOneWidget);
      expect(
        find.text("Your email is your login, so it can't be changed here."),
        findsOneWidget,
      );
    });

    testWidgets('Save posts the details, refreshes the profile and returns', (
      tester,
    ) async {
      final users = FakeUsersRepository();
      final c = await pumpProfile(tester, users: users, path: '/profile');
      await tester.tap(find.text('Edit personal details'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Neha'), 'Milisha');
      await tester.enterText(find.widgetWithText(TextField, 'Kapoor'), 'Saran');
      await tester.pump();
      await tester.tap(_surface('Save'));
      await tester.pumpAndSettle();

      expect(users.updates, hasLength(1));
      expect(users.updates.single['firstName'], 'Milisha');
      expect(users.updates.single['lastName'], 'Saran');
      expect(c.read(sessionProvider).value!.firstName, 'Milisha');
      expect(locationOf(c), '/profile');
      expect(find.text('Milisha Saran'), findsOneWidget);
      expect(find.text('MS'), findsOneWidget);
    });

    testWidgets('Save is disabled without a first name and while saving', (
      tester,
    ) async {
      final users = FakeUsersRepository()..updateGate = Completer<void>();
      await pumpProfile(tester, users: users, path: '/profile/details');
      await tester.enterText(find.widgetWithText(TextField, 'Neha'), '  ');
      await tester.pump();
      await tester.tap(_surface('Save'));
      await tester.pump();
      expect(users.updates, isEmpty);

      await tester.enterText(find.byType(TextField).first, 'Milisha');
      await tester.pump();
      await tester.tap(_surface('Save'));
      await tester.pump();
      await tester.tap(_surface('Save'));
      await tester.pump();
      expect(users.updates, hasLength(1));
      users.updateGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a rejected save shows the server message and stays', (
      tester,
    ) async {
      final users = FakeUsersRepository()
        ..updateError = const ApiError(
          status: 422,
          message: 'Phone is invalid',
        );
      final c = await pumpProfile(
        tester,
        users: users,
        path: '/profile/details',
      );
      await tester.enterText(find.byType(TextField).first, 'Milisha');
      await tester.pump();
      await tester.tap(_surface('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Phone is invalid'), findsOneWidget);
      expect(locationOf(c), '/profile/details');
    });

    testWidgets('the avatar camera says coming soon', (tester) async {
      await pumpProfile(tester, path: '/profile/details');
      await tester.tap(_surface('Change photo'));
      await tester.pumpAndSettle();
      expect(find.text('Coming soon'), findsWidgets);
    });
  });

  group('Categories', () {
    testWidgets('lists the categories', (tester) async {
      await pumpProfile(tester, path: '/profile/categories');
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Stay'), findsOneWidget);
    });

    testWidgets('a failed load shows the message and retries', (tester) async {
      final cats = FakeCategoriesRepository()
        ..listError = const ApiError(status: 500, message: 'Server is down');
      await pumpProfile(tester, categories: cats, path: '/profile/categories');
      expect(find.text('Server is down'), findsOneWidget);
      cats.listError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Food'), findsOneWidget);
    });

    testWidgets('creating Coffee posts the coffee icon and amber', (
      tester,
    ) async {
      final cats = FakeCategoriesRepository();
      await pumpProfile(tester, categories: cats, path: '/profile/categories');
      await tester.tap(_surface('Add category'));
      await tester.pumpAndSettle();
      expect(find.text('New category'), findsOneWidget);
      // Nothing is posted without a name.
      expect(
        tester.widget<BrutalButton>(_button('Add category')).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), '  Coffee ');
      await tester.pump();
      await tester.tap(_surface('Coffee icon'));
      await tester.tap(_swatch('Amber'));
      await tester.pump();
      await tester.tap(_button('Add category'));
      await tester.pumpAndSettle();

      expect(cats.written, [
        {'name': 'Coffee', 'icon': 'local_cafe', 'color': '#FAC775'},
      ]);
      // The sheet closed and the list reloaded.
      expect(find.text('New category'), findsNothing);
      expect(find.text('Coffee'), findsOneWidget);
    });

    testWidgets('the sheet offers 12 icons and 6 colors', (tester) async {
      await pumpProfile(tester, path: '/profile/categories');
      await tester.tap(_surface('Add category'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is BrutalSurface && (w.semanticLabel ?? '').endsWith(' icon'),
        ),
        findsNWidgets(12),
      );
      for (final name in ['Amber', 'Lilac', 'Mint', 'Pink', 'Blue', 'Peach']) {
        expect(_swatch(name), findsOneWidget);
      }
    });

    testWidgets('a refused create keeps the sheet open with the message', (
      tester,
    ) async {
      final cats = FakeCategoriesRepository()
        ..writeError = const ApiError(
          status: 422,
          message: 'Name has already been taken',
        );
      await pumpProfile(tester, categories: cats, path: '/profile/categories');
      await tester.tap(_surface('Add category'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Food');
      await tester.pump();
      await tester.tap(_button('Add category'));
      await tester.pumpAndSettle();
      expect(find.text('Name has already been taken'), findsOneWidget);
      expect(find.text('New category'), findsOneWidget);
    });

    testWidgets('the save button is disabled while posting', (tester) async {
      final cats = FakeCategoriesRepository()..writeGate = Completer<void>();
      await pumpProfile(tester, categories: cats, path: '/profile/categories');
      await tester.tap(_surface('Add category'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Coffee');
      await tester.pump();
      await tester.tap(_button('Add category'));
      await tester.pump();
      await tester.tap(_button('Add category'));
      await tester.pump();
      expect(cats.written, hasLength(1));
      expect(
        tester.widget<BrutalButton>(_button('Add category')).onPressed,
        isNull,
      );
      cats.writeGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('editing a category sends its new name, icon and color', (
      tester,
    ) async {
      final cats = FakeCategoriesRepository();
      await pumpProfile(tester, categories: cats, path: '/profile/categories');
      await tester.tap(find.byTooltip('Food options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit category'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Eating out');
      await tester.pump();
      await tester.tap(_surface('Gift icon'));
      await tester.tap(_swatch('Mint'));
      await tester.pump();
      await tester.tap(_button('Save'));
      await tester.pumpAndSettle();
      expect(cats.written, [
        {
          'id': foodCategory.id,
          'name': 'Eating out',
          'icon': 'redeem',
          'color': '#5DCAA5',
        },
      ]);
      expect(find.text('Eating out'), findsOneWidget);
    });

    testWidgets('deleting asks first and shows a refusal as is', (
      tester,
    ) async {
      final cats = FakeCategoriesRepository();
      await pumpProfile(tester, categories: cats, path: '/profile/categories');
      await tester.tap(find.byTooltip('Food options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(cats.written, isEmpty);

      cats.writeError = const ApiError(
        status: 422,
        message: 'Category is used by expenses',
      );
      await tester.tap(_button('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Category is used by expenses'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);

      cats.writeError = null;
      await tester.tap(_button('Delete'));
      await tester.pumpAndSettle();
      expect(cats.written.last, {'id': foodCategory.id});
      expect(find.text('Food'), findsNothing);
    });
  });

  group('Activity', () {
    testWidgets('shows Coming soon and makes no network calls', (tester) async {
      final adapter = _CountingAdapter();
      final client = ApiClient(
        Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter,
      );
      await pumpProfile(tester, client: client, path: '/activity');
      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.text('Activity'), findsWidgets);
      expect(adapter.requests, 0);
    });
  });
}
