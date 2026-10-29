import 'dart:async';

import 'package:dio/dio.dart';
import 'package:ezsplit_mobile/data/api_error.dart';
import 'package:ezsplit_mobile/data/api_client.dart';
import 'package:ezsplit_mobile/data/summary_repository.dart';
import 'package:ezsplit_mobile/state/offline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

List<Override> _repos() => repoOverrides(
  FakeGroupsRepository(groups: [makeGroup(7, 'Goa trip')]),
  FakeUsersRepository(),
);

void main() {
  testWidgets('with no session, /groups goes to /login', (tester) async {
    final c = await pumpApp(tester, FakeAuthRepository());
    routerOf(c).go('/groups');
    await tester.pumpAndSettle();
    expect(locationOf(c), '/login');
    expect(find.text('Split bills. Stay friends.'), findsOneWidget);
  });

  testWidgets('public routes stay reachable without a session', (tester) async {
    final c = await pumpApp(tester, FakeAuthRepository());
    routerOf(c).go('/forgot');
    await tester.pumpAndSettle();
    expect(locationOf(c), '/forgot');
  });

  testWidgets('with a session, /login goes to /home', (tester) async {
    final c = await pumpApp(tester, FakeAuthRepository(current: testUser));
    routerOf(c).go('/login');
    await tester.pumpAndSettle();
    expect(locationOf(c), '/home');
  });

  testWidgets('waits on a splash while the session loads', (tester) async {
    final gate = Completer<void>();
    final repo = FakeAuthRepository(current: testUser, currentGate: gate);
    final c = await pumpApp(tester, repo, settle: false);
    expect(locationOf(c), '/splash');
    expect(find.text('Log in'), findsNothing);
    expect(find.bySemanticsLabel('Loading EzSplit'), findsOneWidget);
    expect(find.text('EzSplit'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(locationOf(c), '/home');
  });

  testWidgets('holds the splash for its minimum time on a fast start', (
    tester,
  ) async {
    final c = await pumpApp(
      tester,
      FakeAuthRepository(current: testUser),
      settle: false,
      splashMin: const Duration(milliseconds: 1000),
    );
    await tester.pump(const Duration(milliseconds: 900));
    expect(locationOf(c), '/splash');
    expect(find.text('EzSplit'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(locationOf(c), '/home');
  });

  testWidgets('a slow session check does not add the minimum on top', (
    tester,
  ) async {
    final gate = Completer<void>();
    final c = await pumpApp(
      tester,
      FakeAuthRepository(current: testUser, currentGate: gate),
      settle: false,
      splashMin: const Duration(milliseconds: 1000),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    expect(locationOf(c), '/splash');

    gate.complete();
    await tester.pumpAndSettle();
    expect(locationOf(c), '/home');
  });

  testWidgets('tabs switch screens', (tester) async {
    final c = await pumpApp(
      tester,
      FakeAuthRepository(current: testUser),
      extraOverrides: _repos(),
    );
    for (final tab in ['Groups', 'Activity', 'Profile', 'Home']) {
      await tester.tap(find.widgetWithText(InkWell, tab));
      await tester.pumpAndSettle();
      expect(locationOf(c), '/${tab.toLowerCase()}');
    }
  });

  testWidgets('the tab bar fits 360 px wide at 2x text and keeps 44 px taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = await pumpApp(
      tester,
      FakeAuthRepository(current: testUser),
      extraOverrides: _repos(),
    );
    routerOf(c).go('/groups');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final tab in ['Home', 'Groups', 'Activity', 'Profile']) {
      final item = find.widgetWithText(InkWell, tab);
      expect(item, findsOneWidget);
      final size = tester.getSize(item);
      expect(size.height, greaterThanOrEqualTo(44), reason: tab);
      expect(size.width, greaterThanOrEqualTo(44), reason: tab);
      final right = tester.getTopRight(item).dx;
      expect(right, lessThanOrEqualTo(360), reason: tab);
    }
  });

  testWidgets('new group and settings hide the tab bar', (tester) async {
    final c = await pumpApp(
      tester,
      FakeAuthRepository(current: testUser),
      extraOverrides: _repos(),
    );
    routerOf(c).go('/groups');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InkWell, 'Profile'), findsOneWidget);

    for (final path in ['/groups/new', '/groups/7/settings']) {
      routerOf(c).go(path);
      await tester.pumpAndSettle();
      expect(locationOf(c), path);
      expect(
        find.widgetWithText(InkWell, 'Profile'),
        findsNothing,
        reason: path,
      );
    }
  });

  testWidgets('every route in the plan resolves', (tester) async {
    final c = await pumpApp(
      tester,
      FakeAuthRepository(current: testUser),
      extraOverrides: _repos(),
    );
    for (final path in [
      '/groups/new',
      '/groups/7?view=balances',
      '/groups/7/settings',
      '/groups/7/expenses/new',
      '/expenses/3',
      '/expenses/3/edit',
      '/profile/details',
      '/profile/categories',
    ]) {
      routerOf(c).go(path);
      await tester.pumpAndSettle();
      expect(locationOf(c), path);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'the offline banner shows on a failed call and hides on the next',
    (tester) async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      final adapter = DioAdapter(dio: dio);
      final client = ApiClient(dio);
      final c = await pumpApp(
        tester,
        FakeAuthRepository(current: testUser),
        client: client,
        // Keeps the dashboard's own call from touching the offline flag.
        extraOverrides: [
          summaryRepositoryProvider.overrideWithValue(FakeSummaryRepository()),
        ],
      );
      expect(find.text("You're offline. Changes won't save."), findsNothing);

      adapter.onGet(
        '/groups',
        (s) => s.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/groups'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );
      await tester.runAsync(
        () => expectLater(client.get('/groups'), throwsA(anything)),
      );
      await tester.pump();
      expect(c.read(offlineProvider), isTrue);
      expect(find.text("You're offline. Changes won't save."), findsOneWidget);

      adapter.onGet('/ping', (s) => s.reply(200, {'ok': true}));
      await tester.runAsync(() => client.get('/ping'));
      await tester.pump();
      expect(find.text("You're offline. Changes won't save."), findsNothing);
    },
  );

  testWidgets('a signed-in user on /invite goes to /home', (tester) async {
    final c = await pumpApp(tester, FakeAuthRepository(current: testUser));
    routerOf(c).go('/invite?token=abc&email=a@b.co');
    await tester.pumpAndSettle();
    expect(locationOf(c), '/home');
  });

  testWidgets('/invite without a token goes to /login', (tester) async {
    final c = await pumpApp(tester, FakeAuthRepository());
    routerOf(c).go('/invite');
    await tester.pumpAndSettle();
    expect(locationOf(c), '/login');
    routerOf(c).go('/invite?email=a@b.co');
    await tester.pumpAndSettle();
    expect(locationOf(c), '/login');
  });

  testWidgets('/invite with only a token opens the invite', (tester) async {
    final c = await pumpApp(tester, FakeAuthRepository());
    routerOf(c).go('/invite?token=abc');
    await tester.pumpAndSettle();
    expect(locationOf(c), '/invite?token=abc');
    expect(find.text('Join ezsplit'), findsOneWidget);
  });

  testWidgets('a failed session load lands on /login without an error', (
    tester,
  ) async {
    final repo = FakeAuthRepository()
      ..currentError = const ApiError(message: 'Offline');
    final c = await pumpApp(tester, repo);
    expect(locationOf(c), '/login');
    expect(tester.takeException(), isNull);
  });

  group('incoming links', () {
    late StreamController<Uri> links;
    setUp(() => links = StreamController<Uri>());
    tearDown(() => links.close());

    testWidgets('a valid link opens the invite prefilled, without submitting', (
      tester,
    ) async {
      final repo = FakeAuthRepository();
      final c = await pumpApp(tester, repo, links: links.stream);
      links.add(
        Uri.parse(
          'ezsplit://register?token=abc&email_address=neha%40gmail.com',
        ),
      );
      await tester.pumpAndSettle();
      expect(locationOf(c), startsWith('/invite?'));
      expect(find.text('neha@gmail.com'), findsOneWidget);
      expect(find.text('Join ezsplit'), findsOneWidget);
      expect(repo.invites, isEmpty);
    });

    testWidgets('a scanned QR link opens the invite with no email', (
      tester,
    ) async {
      final c = await pumpApp(
        tester,
        FakeAuthRepository(),
        links: links.stream,
      );
      links.add(Uri.parse('https://10.0.0.5/register?token=abc'));
      await tester.pumpAndSettle();
      expect(locationOf(c), '/invite?token=abc');
      expect(find.text('Join ezsplit'), findsOneWidget);
    });

    testWidgets('malformed and foreign links leave the route alone', (
      tester,
    ) async {
      final c = await pumpApp(
        tester,
        FakeAuthRepository(),
        links: links.stream,
      );
      for (final link in [
        'ezsplit://register?token=%C0%AF&email_address=a@b.c',
        'ezsplit://register?email_address=a@b.co',
        'ezsplit://groups/1',
        'https://evil.example/home',
      ]) {
        links.add(Uri.parse(link));
        await tester.pumpAndSettle();
        expect(locationOf(c), '/login', reason: link);
      }
    });
  });
}
