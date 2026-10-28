import 'package:dio/dio.dart';
import 'package:ezsplit_mobile/data/api_client.dart';
import 'package:ezsplit_mobile/data/models.dart';
import 'package:ezsplit_mobile/data/users_repository.dart';
import 'package:ezsplit_mobile/screens/groups/groups_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../support/fakes.dart';
import 'groups_test.dart' show pumpScreen;

const _request = {
  'id': 7,
  'created_at': '2026-10-28T10:00:00Z',
  'inviter': {
    'id': 2,
    'first_name': 'Riya',
    'last_name': 'S',
    'email_address': 'riya@x.com',
  },
};

void main() {
  late DioAdapter adapter;
  late UsersRepository users;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = DioAdapter(dio: dio);
    users = UsersRepository(ApiClient(dio));
  });

  Future<ProviderContainer> pump(WidgetTester tester) => pumpScreen(
    tester,
    const GroupsScreen(),
    FakeGroupsRepository(groups: [makeGroup(1, 'Goa trip')]),
    users: _Users(users),
  );

  void listReturns(List<Map<String, Object?>> data) =>
      adapter.onGet('/invitations', (s) => s.reply(200, {'data': data}));

  testWidgets('the section is hidden when there are no requests', (
    tester,
  ) async {
    listReturns([]);
    await pump(tester);
    expect(find.text('Friend requests'), findsNothing);
    expect(find.text('Goa trip'), findsOneWidget);
  });

  testWidgets('Accept posts to /accept and the row disappears', (tester) async {
    listReturns([_request]);
    adapter.onPost(
      '/invitations/7/accept',
      (s) => s.reply(200, {'message': 'You are now friends with Riya S.'}),
    );
    await pump(tester);
    expect(find.text('Friend requests'), findsOneWidget);
    expect(find.text('Riya S'), findsOneWidget);
    expect(find.text('riya@x.com'), findsOneWidget);

    listReturns([]);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(find.text('Friend requests'), findsNothing);
    expect(find.text('You are now friends with Riya S.'), findsOneWidget);
  });

  testWidgets('Decline posts to /decline and the row disappears', (
    tester,
  ) async {
    listReturns([_request]);
    adapter.onPost(
      '/invitations/7/decline',
      (s) => s.reply(200, {'message': 'Invitation declined.'}),
    );
    await pump(tester);

    listReturns([]);
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(find.text('Friend requests'), findsNothing);
    expect(find.text('Invitation declined.'), findsOneWidget);
  });

  testWidgets('an error shows the message and keeps the row', (tester) async {
    listReturns([_request]);
    adapter.onPost(
      '/invitations/7/accept',
      (s) => s.reply(404, {
        'errors': ['Invitation not found.'],
      }),
    );
    await pump(tester);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(find.text('Invitation not found.'), findsOneWidget);
    expect(find.text('Riya S'), findsOneWidget);
  });
}

/// A friends fake whose requests come from the real repository.
class _Users extends FakeUsersRepository {
  _Users(this._real);

  final UsersRepository _real;

  @override
  Future<List<FriendRequest>> friendRequests() => _real.friendRequests();

  @override
  Future<String> acceptFriendRequest(int id) => _real.acceptFriendRequest(id);

  @override
  Future<String> declineFriendRequest(int id) => _real.declineFriendRequest(id);
}
