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
import 'package:qr_flutter/qr_flutter.dart';
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

FakeAuthRepository _fullAuth() => FakeAuthRepository(
  current: User(
    id: 1,
    firstName: 'Neha',
    lastName: 'Kapoor',
    email: 'neha@gmail.com',
    phone: '9876543210',
    dob: DateTime(1996, 3, 12),
  ),
);

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

    testWidgets('Invite a friend sends an invite and confirms it', (
      tester,
    ) async {
      final users = FakeUsersRepository();
      await pumpProfile(tester, users: users);
      await tester.tap(find.text('Invite a friend'));
      await tester.pumpAndSettle();
      expect(find.text('Invite by email'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'sam@example.com');
      await tester.pump();
      await tester.tap(find.text('Send invite'));
      await tester.pumpAndSettle();
      expect(users.invited, ['sam@example.com']);
      expect(find.text('Invite sent to sam@example.com.'), findsOneWidget);
    });

    testWidgets('Invite a friend shows a one-use QR code and makes a new one', (
      tester,
    ) async {
      final users = FakeUsersRepository();
      await pumpProfile(tester, users: users);
      await tester.tap(find.text('Invite a friend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show QR code'));
      await tester.pumpAndSettle();

      expect(find.text('Scan to join'), findsOneWidget);
      // The sheet keys the code by the link it encodes.
      Finder code(String url) => find.byKey(ValueKey(url));
      expect(find.byType(QrImageView), findsOneWidget);
      expect(code('http://10.0.0.5:3100/register?token=qr1'), findsOneWidget);
      expect(
        find.text('Works once, for one person. Expires in 7 days.'),
        findsOneWidget,
      );

      await tester.tap(find.text('New code'));
      await tester.pumpAndSettle();
      expect(users.qrInvites, 2);
      expect(code('http://10.0.0.5:3100/register?token=qr2'), findsOneWidget);
    });

    testWidgets('the QR code stays dark on white in dark mode', (tester) async {
      final c = await pumpProfile(tester);
      c.read(themeModeProvider.notifier).set(ThemeMode.dark);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invite a friend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show QR code'));
      await tester.pumpAndSettle();

      final card = tester.widget<BrutalCard>(
        find.ancestor(
          of: find.byType(QrImageView),
          matching: find.byType(BrutalCard),
        ),
      );
      expect(card.color, Colors.white);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the QR sheet offers a retry when the code fails', (
      tester,
    ) async {
      final users = FakeUsersRepository()
        ..qrInviteError = const ApiError(message: 'Offline');
      await pumpProfile(tester, users: users);
      await tester.tap(find.text('Invite a friend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show QR code'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);

      users.qrInviteError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
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
      final c = await pumpProfile(
        tester,
        auth: _fullAuth(),
        users: users,
        path: '/profile',
      );
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
      expect(users.updates.single['phone'], '9876543210');
      expect(users.updates.single['dob'], DateTime(1996, 3, 12));
      expect(isoDate(users.updates.single['dob'] as DateTime), '1996-03-12');
      expect(c.read(sessionProvider).value!.firstName, 'Milisha');
      expect(locationOf(c), '/profile');
      expect(find.text('Milisha Saran'), findsOneWidget);
      expect(find.text('MS'), findsOneWidget);
    });

    for (final (field, current) in [
      ('Neha', 'first name'),
      ('Kapoor', 'last name'),
      ('9876543210', 'phone'),
    ]) {
      testWidgets('an empty $current blocks the save with Required', (
        tester,
      ) async {
        final users = FakeUsersRepository();
        await pumpProfile(
          tester,
          auth: _fullAuth(),
          users: users,
          path: '/profile/details',
        );
        expect(find.text('Required'), findsNothing);
        await tester.enterText(find.widgetWithText(TextField, field), '  ');
        await tester.pump();
        await tester.tap(_surface('Save'));
        await tester.pumpAndSettle();
        expect(find.text('Required'), findsOneWidget);
        expect(users.updates, isEmpty);
      });
    }

    testWidgets('a missing date of birth blocks the save with Required', (
      tester,
    ) async {
      final users = FakeUsersRepository();
      await pumpProfile(
        tester,
        auth: FakeAuthRepository(
          current: const User(
            id: 1,
            firstName: 'Neha',
            lastName: 'Kapoor',
            email: 'neha@gmail.com',
            phone: '9876543210',
          ),
        ),
        users: users,
        path: '/profile/details',
      );
      await tester.tap(_surface('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      expect(users.updates, isEmpty);
    });

    testWidgets('the date picker stops at today', (tester) async {
      await pumpProfile(tester, auth: _fullAuth(), path: '/profile/details');
      await tester.tap(find.text('12 Mar 1996'));
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      final now = DateTime.now();
      expect(
        DateUtils.dateOnly(picker.lastDate),
        DateTime(now.year, now.month, now.day),
      );
    });

    testWidgets('Save posts once and is inert while saving', (tester) async {
      final users = FakeUsersRepository()..updateGate = Completer<void>();
      await pumpProfile(
        tester,
        auth: _fullAuth(),
        users: users,
        path: '/profile/details',
      );
      await tester.tap(_surface('Save'));
      await tester.pump();
      await tester.tap(_surface('Save'));
      await tester.pump();
      expect(users.updates, hasLength(1));
      users.updateGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a rejected save shows the server message near the top', (
      tester,
    ) async {
      final users = FakeUsersRepository()
        ..updateError = const ApiError(
          status: 422,
          message: 'Phone is invalid',
        );
      final c = await pumpProfile(
        tester,
        auth: _fullAuth(),
        users: users,
        path: '/profile/details',
      );
      await tester.tap(_surface('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Phone is invalid'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Phone is invalid')).dy,
        lessThan(tester.getTopLeft(find.text('First name')).dy),
      );
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

    testWidgets('editing keeps an icon that is not a preset', (tester) async {
      const hotel = Category(
        id: 7,
        name: 'Hotels',
        icon: 'hotel',
        color: '#B5D4F4',
      );
      final cats = FakeCategoriesRepository([hotel]);
      await pumpProfile(tester, categories: cats, path: '/profile/categories');
      await tester.tap(find.byTooltip('Hotels options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Stays');
      await tester.pump();
      await tester.tap(_button('Save'));
      await tester.pumpAndSettle();
      expect(cats.written, [
        {'id': 7, 'name': 'Stays', 'icon': 'hotel', 'color': '#B5D4F4'},
      ]);
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
