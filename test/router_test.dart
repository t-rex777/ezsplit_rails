import 'dart:async';

import 'package:dio/dio.dart';
import 'package:ezsplit_mobile/data/api_error.dart';
import 'package:ezsplit_mobile/data/api_client.dart';
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
    final c = await pumpApp(tester, repo);
    expect(locationOf(c), '/splash');
    expect(find.text('Log in'), findsNothing);

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

  testWidgets('/invite without params goes to /login', (tester) async {
    final c = await pumpApp(tester, FakeAuthRepository());
    routerOf(c).go('/invite');
    await tester.pumpAndSettle();
    expect(locationOf(c), '/login');
    routerOf(c).go('/invite?token=abc');
    await tester.pumpAndSettle();
    expect(locationOf(c), '/login');
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
        'ezsplit://register?token=abc',
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
