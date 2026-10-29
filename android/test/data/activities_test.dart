import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ezsplit_mobile/data/activities_repository.dart';
import 'package:ezsplit_mobile/data/api_client.dart';
import 'package:ezsplit_mobile/data/jsonapi.dart';
import 'package:ezsplit_mobile/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

dynamic fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync());

void main() {
  group('ActivityEntry.fromJson', () {
    final page = JsonApiDoc(fixture('activities.json') as Map<String, dynamic>)
        .page(ActivityEntry.fromJson);
    final byId = {for (final a in page.items) a.id: a};

    test('reads every entry, newest first', () {
      expect(page.items.map((a) => a.action), [
        ActivityAction.settled,
        ActivityAction.deleted,
        ActivityAction.created,
        ActivityAction.updated,
        ActivityAction.created,
        ActivityAction.created,
      ]);
      expect(page.nextPage, isNull);
    });

    test('an edit keeps the expense before and after', () {
      final edit = byId[3]!;
      expect(edit.actorName, 'Riya Shah');
      expect(edit.groupName, 'Goa trip');
      expect(edit.before!.paise, 240000);
      expect(edit.after!.paise, 300000);
      expect(edit.before!.payerName, 'Neha Kapoor');
      expect(edit.after!.payerName, 'Riya Shah');
      expect(edit.changedFields, ['amount', 'payer', 'shares']);
      expect(edit.after!.shares.map((s) => s.paise), [75000, 150000, 75000]);
    });

    test('a delete keeps what was removed', () {
      final removed = byId[5]!;
      expect(removed.after, isNull);
      expect(removed.current.name, 'Cab to airport');
      expect(removed.current.shares.map((s) => s.name), [
        'Neha Kapoor',
        'Riya Shah',
      ]);
    });
  });

  group('settlement entries', () {
    final page = JsonApiDoc(fixture('activities.json') as Map<String, dynamic>)
        .page(ActivityEntry.fromJson);

    test('a settle-up keeps who paid whom, how much and the note', () {
      final paid = page.items.first;
      expect(paid.settlementId, 1);
      expect(paid.expenseId, isNull);
      expect(paid.payment!.paise, 50000);
      expect(paid.payment!.payerName, 'Riya Shah');
      expect(paid.payment!.payeeId, 1);
      expect(paid.payment!.payeeName, 'Neha Kapoor');
      expect(paid.payment!.notes, 'UPI');
      expect(paid.subjectPaise, 50000);
      expect(paid.groupName, 'Goa trip');
    });
  });

  group('ActivitiesRepository', () {
    late DioAdapter adapter;
    late ActivitiesRepository repo;
    late List<RequestOptions> sent;

    setUp(() {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      adapter = DioAdapter(dio: dio);
      sent = [];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            sent.add(o);
            h.next(o);
          },
        ),
      );
      repo = ActivitiesRepository(ApiClient(dio));
    });

    test('sends no group_id for all groups', () async {
      adapter.onGet(
        '/activities',
        (s) => s.reply(200, fixture('activities.json')),
        queryParameters: {'page': 1},
      );
      final page = await repo.list(const AllActivity());
      expect(sent.single.queryParameters, {'page': 1});
      expect(page.items, hasLength(6));
    });

    test('sends the group id, or none for friend expenses', () async {
      adapter
        ..onGet(
          '/activities',
          (s) => s.reply(200, fixture('activities.json')),
          queryParameters: {'page': 2, 'group_id': 7},
        )
        ..onGet(
          '/activities',
          (s) => s.reply(200, fixture('activities.json')),
          queryParameters: {'page': 1, 'group_id': 'none'},
        );
      await repo.list(const GroupActivity(7), page: 2);
      await repo.list(const FriendActivity());
      expect(sent[0].queryParameters, {'page': 2, 'group_id': 7});
      expect(sent[1].queryParameters, {'page': 1, 'group_id': 'none'});
    });
  });
}
