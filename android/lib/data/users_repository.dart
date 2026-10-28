import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session.dart';
import 'api_client.dart';
import 'jsonapi.dart';
import 'models.dart';

class UsersRepository {
  UsersRepository(this._api);

  final ApiClient _api;

  /// The signed-in user's friends.
  Future<List<User>> friends() => allPages((page) async {
    final json = await _api.get('/users', query: {if (page > 1) 'page': page});
    return parseOrThrow(() => JsonApiDoc(json).page(User.fromJson));
  });

  /// Searches friends by name or email. The server returns the first 5.
  Future<List<User>> search(String term) async {
    final json = await _api.get('/users/search', query: {'term': term});
    return parseOrThrow(
      () => [for (final r in JsonApiDoc(json).list) User.fromJson(r)],
    );
  }

  Future<User> me() async => _user(await _api.get('/me'));

  Future<User> updateMe({
    String? firstName,
    String? lastName,
    String? phone,
    DateTime? dob,
  }) async => _user(
    await _api.patch(
      '/me',
      body: {
        'user': {
          'first_name': ?firstName,
          'last_name': ?lastName,
          'phone': ?phone,
          'date_of_birth': ?(dob == null ? null : isoDate(dob)),
        },
      },
    ),
  );

  /// Returns the server's message, for example "Invitation sent successfully."
  Future<String> invite(String email) async {
    final json = await _api.post(
      '/invitations',
      body: {
        'invitation': {'email_address': email},
      },
    );
    return parseOrThrow(() => json['message'] as String);
  }

  /// Friend requests waiting for the signed-in user.
  Future<List<FriendRequest>> friendRequests() async {
    final json = await _api.get('/invitations');
    return parseOrThrow(
      () => [
        for (final r in json['data'] as List)
          FriendRequest.fromJson(r as Map<String, dynamic>),
      ],
    );
  }

  /// Returns the server's message, for example "You are now friends with Riya S."
  Future<String> acceptFriendRequest(int id) => _answer(id, 'accept');

  Future<String> declineFriendRequest(int id) => _answer(id, 'decline');

  Future<String> _answer(int id, String action) async {
    final json = await _api.post('/invitations/$id/$action');
    return parseOrThrow(() => json['message'] as String);
  }

  User _user(Map<String, dynamic> json) =>
      parseOrThrow(() => User.fromJson(JsonApiDoc(json).data));
}

final usersRepositoryProvider = Provider<UsersRepository>(
  (ref) => UsersRepository(ref.watch(apiClientProvider)),
);
