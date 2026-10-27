import 'package:ezsplit_mobile/data/api_error.dart';
import 'package:ezsplit_mobile/screens/groups/group_settings_screen.dart';
import 'package:ezsplit_mobile/screens/groups/groups_screen.dart';
import 'package:ezsplit_mobile/screens/groups/new_group_screen.dart';
import 'package:ezsplit_mobile/state/group_icons.dart';
import 'package:ezsplit_mobile/state/summary.dart';
import 'package:ezsplit_mobile/theme/app_theme.dart';
import 'package:ezsplit_mobile/widgets/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  Widget screen,
  FakeGroupsRepository groups, {
  FakeUsersRepository? users,
  FakeSummaryRepository? summary,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overridesFor(FakeAuthRepository(current: testUser)),
        ...repoOverrides(
          groups,
          users ?? FakeUsersRepository(),
          summary: summary,
        ),
      ],
      child: MaterialApp(theme: buildTheme(Brightness.light), home: screen),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

void main() {
  group('Groups list', () {
    testWidgets('no groups shows the empty state', (tester) async {
      await pumpScreen(tester, const GroupsScreen(), FakeGroupsRepository());
      expect(find.text('Start your first group'), findsOneWidget);
      expect(find.text('New group'), findsOneWidget);
    });

    testWidgets('the Owes me filter keeps only groups owed money', (
      tester,
    ) async {
      final repo = FakeGroupsRepository(
        groups: [
          makeGroup(1, 'Goa trip', net: 185000),
          makeGroup(2, 'Flatmates', net: -62000),
          makeGroup(3, 'Office lunch'),
        ],
      );
      await pumpScreen(tester, const GroupsScreen(), repo);
      expect(find.text('Goa trip'), findsOneWidget);
      expect(find.text('Flatmates'), findsOneWidget);
      expect(find.text('Office lunch'), findsOneWidget);

      await tester.tap(find.text('Owes me'));
      await tester.pumpAndSettle();
      expect(find.text('Goa trip'), findsOneWidget);
      expect(find.text('Flatmates'), findsNothing);
      expect(find.text('Office lunch'), findsNothing);

      await tester.tap(find.text('I owe'));
      await tester.pumpAndSettle();
      expect(find.text('Flatmates'), findsOneWidget);
      expect(find.text('Goa trip'), findsNothing);
    });

    testWidgets('search narrows by name', (tester) async {
      final repo = FakeGroupsRepository(
        groups: [makeGroup(1, 'Goa trip'), makeGroup(2, 'Flatmates')],
      );
      await pumpScreen(tester, const GroupsScreen(), repo);
      await tester.enterText(find.byType(TextField), 'goa');
      await tester.pumpAndSettle();
      expect(find.text('Goa trip'), findsOneWidget);
      expect(find.text('Flatmates'), findsNothing);
    });

    testWidgets('a two-member group says just you two', (tester) async {
      final repo = FakeGroupsRepository(
        groups: [
          makeGroup(1, 'Riya', net: 60000, members: [testUser, riya]),
          makeGroup(2, 'Goa trip', net: 100),
        ],
      );
      await pumpScreen(tester, const GroupsScreen(), repo);
      expect(find.text('just you two'), findsOneWidget);
      expect(find.text('3 members'), findsOneWidget);
    });

    testWidgets('amounts carry a word as well as a sign', (tester) async {
      final repo = FakeGroupsRepository(
        groups: [
          makeGroup(1, 'Goa trip', net: 185000),
          makeGroup(2, 'Flatmates', net: -62000),
          makeGroup(3, 'Office lunch'),
        ],
      );
      await pumpScreen(tester, const GroupsScreen(), repo);
      expect(find.text('+₹1,850'), findsOneWidget);
      expect(find.text('owes you'), findsOneWidget);
      expect(find.text('−₹620'), findsOneWidget);
      expect(find.text('you owe'), findsOneWidget);
      expect(find.text('settled'), findsOneWidget);
    });

    testWidgets('a long name ellipsizes and a crore amount stays whole', (
      tester,
    ) async {
      final name = List.filled(80, 'a').join();
      final repo = FakeGroupsRepository(
        groups: [makeGroup(1, name, net: 1000000000)],
      );
      await pumpScreen(tester, const GroupsScreen(), repo);
      expect(tester.takeException(), isNull);
      final title = tester.widget<Text>(find.text(name));
      expect(title.overflow, TextOverflow.ellipsis);
      expect(title.maxLines, 1);
      expect(find.text('+₹1,00,00,000'), findsOneWidget);
    });

    testWidgets('sorts by name and by amount', (tester) async {
      final repo = FakeGroupsRepository(
        groups: [
          makeGroup(1, 'beta', net: 100),
          makeGroup(2, 'Alpha', net: -900),
          makeGroup(3, 'Gamma', net: 500),
        ],
      );
      await pumpScreen(tester, const GroupsScreen(), repo);
      List<String> order() => [
        for (final w in tester.widgetList<Text>(
          find.byKey(const ValueKey('group-name')),
        ))
          w.data!,
      ];
      await tester.tap(find.bySemanticsLabel('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      expect(order(), ['Alpha', 'beta', 'Gamma']);

      await tester.tap(find.bySemanticsLabel('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amount'));
      await tester.pumpAndSettle();
      expect(order(), ['Alpha', 'Gamma', 'beta']);
    });
  });

  group('visibleGroups', () {
    test('recent activity puts groups without activity last', () {
      final groups = [
        makeGroup(1, 'none'),
        makeGroup(2, 'old', lastActivityAt: DateTime(2026, 1, 1)),
        makeGroup(3, 'new', lastActivityAt: DateTime(2026, 6, 1)),
      ];
      expect(
        [for (final g in visibleGroups(groups)) g.name],
        ['new', 'old', 'none'],
      );
    });
  });

  group('New group', () {
    testWidgets('Create is disabled until the name is filled', (tester) async {
      await pumpScreen(tester, const NewGroupScreen(), FakeGroupsRepository());
      BrutalButton create() => tester.widget<BrutalButton>(
        find.widgetWithText(BrutalButton, 'Create group'),
      );
      expect(create().onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.pump();
      expect(create().onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'Goa trip');
      await tester.pump();
      expect(create().onPressed, isNotNull);
    });

    testWidgets('Create posts the group, then adds the picked friends', (
      tester,
    ) async {
      final groups = FakeGroupsRepository();
      final users = FakeUsersRepository(friendList: [riya, arjun]);
      final c = await pumpScreen(
        tester,
        const NewGroupScreen(),
        groups,
        users: users,
      );
      await tester.enterText(find.byType(TextField).first, 'Goa trip');
      await tester.tap(find.text('Riya Kapoor'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Icon flight'));
      await tester.pump();
      await tester.tap(find.widgetWithText(BrutalButton, 'Create group'));
      await tester.pumpAndSettle();
      expect(groups.calls, ['create Goa trip', 'addMembers 99']);
      expect(groups.added, [
        [3],
      ]);
      expect(c.read(groupIconProvider(99)).value, 'flight');
    });

    testWidgets('invite by email shows the toast and sends nothing else', (
      tester,
    ) async {
      final users = FakeUsersRepository();
      final groups = FakeGroupsRepository();
      await pumpScreen(tester, const NewGroupScreen(), groups, users: users);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not on ezsplit? Invite by email'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'sam@gmail.com');
      await tester.pump();
      await tester.tap(find.widgetWithText(BrutalButton, 'Send invite'));
      await tester.pumpAndSettle();
      expect(users.invited, ['sam@gmail.com']);
      expect(
        find.text('Invite sent. Add sam to the group once they join.'),
        findsOneWidget,
      );
      expect(groups.calls, isEmpty);
    });

    testWidgets('an existing friend shows the server message instead', (
      tester,
    ) async {
      final users = FakeUsersRepository()
        ..inviteMessage = 'sam@gmail.com is already a friend.';
      await pumpScreen(
        tester,
        const NewGroupScreen(),
        FakeGroupsRepository(),
        users: users,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not on ezsplit? Invite by email'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'sam@gmail.com');
      await tester.pump();
      await tester.tap(find.widgetWithText(BrutalButton, 'Send invite'));
      await tester.pumpAndSettle();
      expect(find.text('sam@gmail.com is already a friend.'), findsOneWidget);
    });
  });

  group('Group settings', () {
    final member = makeGroup(7, 'Goa trip', ownerId: 3);
    final owned = makeGroup(7, 'Goa trip', ownerId: 1);

    testWidgets('a member who is not the owner sees Leave, not Delete', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const GroupSettingsScreen(groupId: 7),
        FakeGroupsRepository(groups: [member]),
      );
      expect(find.widgetWithText(BrutalButton, 'Leave group'), findsOneWidget);
      expect(find.widgetWithText(BrutalButton, 'Delete group'), findsNothing);
      expect(find.byTooltip('Edit group'), findsNothing);
      expect(find.byTooltip('Riya options'), findsNothing);
    });

    testWidgets('the owner sees Delete, Edit and member options, not Leave', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const GroupSettingsScreen(groupId: 7),
        FakeGroupsRepository(groups: [owned]),
      );
      expect(find.widgetWithText(BrutalButton, 'Delete group'), findsOneWidget);
      expect(find.widgetWithText(BrutalButton, 'Leave group'), findsNothing);
      expect(find.byTooltip('Edit group'), findsOneWidget);
      expect(find.byTooltip('Riya options'), findsOneWidget);
      expect(find.byTooltip('Neha options'), findsNothing);
    });

    testWidgets('Leave asks first, then shows the server 422 as is', (
      tester,
    ) async {
      final repo = FakeGroupsRepository(groups: [member])
        ..removeError = const ApiError(
          status: 422,
          message: 'Settle up before leaving',
        );
      await pumpScreen(tester, const GroupSettingsScreen(groupId: 7), repo);
      await tester.tap(find.widgetWithText(BrutalButton, 'Leave group'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);

      await tester.tap(find.widgetWithText(BrutalButton, 'Yes, leave'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['removeMember 7 101']);
      expect(find.text('Settle up before leaving'), findsOneWidget);
    });

    testWidgets('leaving and deleting a group reload the dashboard summary', (
      tester,
    ) async {
      for (final (group, button, confirm) in [
        (member, 'Leave group', 'Yes, leave'),
        (owned, 'Delete group', 'Yes, delete'),
      ]) {
        final summary = FakeSummaryRepository();
        final c = await pumpScreen(
          tester,
          const GroupSettingsScreen(groupId: 7),
          FakeGroupsRepository(groups: [group]),
          summary: summary,
        );
        c.listen(monthlySummaryProvider(DateTime(2026, 10)), (_, _) {});
        await tester.pumpAndSettle();
        expect(summary.requested, ['2026-10']);
        await tester.tap(find.widgetWithText(BrutalButton, button));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(BrutalButton, confirm));
        await tester.pumpAndSettle();
        expect(summary.requested, ['2026-10', '2026-10'], reason: button);
      }
    });

    testWidgets('Delete asks before deleting', (tester) async {
      final repo = FakeGroupsRepository(groups: [owned]);
      await pumpScreen(tester, const GroupSettingsScreen(groupId: 7), repo);
      await tester.tap(find.widgetWithText(BrutalButton, 'Delete group'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);

      await tester.tap(find.widgetWithText(BrutalButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);

      await tester.tap(find.widgetWithText(BrutalButton, 'Delete group'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(BrutalButton, 'Yes, delete'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['delete 7']);
    });

    testWidgets('Add lists only friends who are not in the group', (
      tester,
    ) async {
      final repo = FakeGroupsRepository(groups: [owned]);
      final users = FakeUsersRepository(friendList: [riya, sam]);
      await pumpScreen(
        tester,
        const GroupSettingsScreen(groupId: 7),
        repo,
        users: users,
      );
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();
      final tiles = find.byType(CheckboxListTile);
      expect(tiles, findsOneWidget);
      expect(
        find.descendant(of: tiles, matching: find.text('Sam Rao')),
        findsOneWidget,
      );

      await tester.tap(find.text('Sam Rao'));
      await tester.pump();
      await tester.tap(find.widgetWithText(BrutalButton, 'Add 1 person'));
      await tester.pumpAndSettle();
      expect(repo.added, [
        [5],
      ]);
    });
  });

  group('groupIconProvider', () {
    test('defaults to group and keeps the saved choice', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(await c.read(groupIconProvider(4).future), 'group');
      await c.read(groupIconProvider(4).notifier).set('flight');
      expect(c.read(groupIconProvider(4)).value, 'flight');
      expect(
        (await SharedPreferences.getInstance()).getString('group_icon_4'),
        'flight',
      );
    });
  });
}
