import 'dart:async';

import 'package:dio/dio.dart';
import 'package:ezsplit_mobile/data/api_client.dart';
import 'package:ezsplit_mobile/state/offline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'support/harness.dart';

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
    final c = await pumpApp(tester, FakeAuthRepository(current: testUser));
    for (final tab in ['Groups', 'Activity', 'Profile', 'Home']) {
      await tester.tap(find.widgetWithText(InkWell, tab));
      await tester.pumpAndSettle();
      expect(locationOf(c), '/${tab.toLowerCase()}');
    }
  });

  testWidgets('every route in the plan resolves', (tester) async {
    final c = await pumpApp(tester, FakeAuthRepository(current: testUser));
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

  testWidgets('the offline banner shows on a failed call and hides on the next', (
    tester,
  ) async {
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
  });
}
