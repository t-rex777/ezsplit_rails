import 'package:ezsplit_mobile/data/api_error.dart';
import 'package:ezsplit_mobile/domain/invite_link.dart';
import 'package:ezsplit_mobile/state/session.dart';
import 'package:ezsplit_mobile/widgets/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  group('parseInviteLink', () {
    test('reads an https link with an encoded email', () {
      final link = parseInviteLink(
        'https://ezsplit.app/register?token=abc&email_address=neha%40gmail.com',
      );
      expect(link?.token, 'abc');
      expect(link?.email, 'neha@gmail.com');
    });

    test('reads the raw @ the server puts in emailed links', () {
      final link = parseInviteLink(
        'https://ezsplit.app/register?token=abc&email_address=neha+x@gmail.com',
      );
      expect(link?.token, 'abc');
      expect(link?.email, 'neha+x@gmail.com');
    });

    test('reads the ezsplit scheme', () {
      final link = parseInviteLink(
        '  ezsplit://register?token=abc&email_address=neha%40gmail.com ',
      );
      expect(link?.token, 'abc');
      expect(link?.email, 'neha@gmail.com');
    });

    test('reads a QR link, which has a token and no email', () {
      final web = parseInviteLink('https://ezsplit.app/register?token=abc');
      expect(web?.token, 'abc');
      expect(web?.email, isNull);
      final app = parseInviteLink('ezsplit://register?token=abc');
      expect(app?.token, 'abc');
      expect(app?.email, isNull);
    });

    test('returns null for text, a missing token, or another path', () {
      expect(parseInviteLink('hello'), isNull);
      expect(parseInviteLink(''), isNull);
      expect(parseInviteLink('https://ezsplit.app/register?token='), isNull);
      expect(
        parseInviteLink('https://ezsplit.app/register?email_address=a@b.co'),
        isNull,
      );
      expect(
        parseInviteLink(
          'https://ezsplit.app/other?token=a&email_address=a@b.co',
        ),
        isNull,
      );
      // Bad UTF-8 throws FormatException, bad percent-encoding ArgumentError.
      expect(
        parseInviteLink('ezsplit://register?token=%C0%AF&email_address=a@b.c'),
        isNull,
      );
      expect(
        parseInviteLink('ezsplit://register?token=%zz&email_address=a@b.c'),
        isNull,
      );
      expect(
        parseInviteLink('ezsplit://login?token=a&email_address=a@b.co'),
        isNull,
      );
    });
  });

  group('Login', () {
    testWidgets('shows the server error', (tester) async {
      final repo = FakeAuthRepository()
        ..loginError = const ApiError(
          status: 401,
          message: 'Invalid email address or password',
        );
      await pumpApp(tester, repo);
      expect(find.text('Split bills. Stay friends.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'neha@gmail.com');
      await tester.enterText(find.byType(TextField).at(1), 'secret1');
      await tester.pump();
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(BrutalButton)).width,
        greaterThan(300),
        reason: 'the button fills the form width',
      );
      expect(find.text('Invalid email address or password'), findsOneWidget);
    });

    testWidgets('signing in lands on Home', (tester) async {
      final repo = FakeAuthRepository();
      final c = await pumpApp(tester, repo);
      await tester.enterText(find.byType(TextField).at(0), 'neha@gmail.com');
      await tester.enterText(find.byType(TextField).at(1), 'secret1');
      await tester.pump();
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(locationOf(c), '/home');
    });

    testWidgets('shows the expired message after the session ends', (
      tester,
    ) async {
      final repo = FakeAuthRepository(current: testUser);
      final c = await pumpApp(tester, repo);
      expect(locationOf(c), '/home');

      c.read(sessionProvider.notifier).expire();
      await tester.pumpAndSettle();

      expect(locationOf(c), '/login');
      expect(find.text('Your session expired. Log in again.'), findsOneWidget);
    });

    testWidgets('the invite link sheet opens the accept invite screen', (
      tester,
    ) async {
      final c = await pumpApp(tester, FakeAuthRepository());
      await tester.tap(find.text('Have an invite link?'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'https://ezsplit.app/register?token=abc&email_address=neha@gmail.com',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Join ezsplit'), findsOneWidget);
      expect(locationOf(c), startsWith('/invite?'));
    });

    testWidgets('the invite link sheet rejects other text', (tester) async {
      await pumpApp(tester, FakeAuthRepository());
      await tester.tap(find.text('Have an invite link?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'hello');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text("That isn't an ezsplit invite link"), findsOneWidget);
    });
  });

  group('Login details', () {
    testWidgets('the expired message shows once', (tester) async {
      final c = await pumpApp(tester, FakeAuthRepository(current: testUser));
      c.read(sessionProvider.notifier).expire();
      await tester.pumpAndSettle();
      expect(find.text('Your session expired. Log in again.'), findsOneWidget);

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back to log in'));
      await tester.pumpAndSettle();
      expect(locationOf(c), '/login');
      expect(find.text('Your session expired. Log in again.'), findsNothing);
    });

    testWidgets('the password is hidden until the toggle flips it', (
      tester,
    ) async {
      await pumpApp(tester, FakeAuthRepository());
      TextField password() =>
          tester.widget<TextField>(find.byType(TextField).at(1));
      expect(password().obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(password().obscureText, isFalse);
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();
      expect(password().obscureText, isTrue);
    });

    testWidgets('Done on the password field logs in', (tester) async {
      final c = await pumpApp(tester, FakeAuthRepository());
      await tester.enterText(find.byType(TextField).at(0), 'neha@gmail.com');
      await tester.enterText(find.byType(TextField).at(1), 'secret1');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(locationOf(c), '/home');
    });

    testWidgets('the paste sheet rejects a malformed invite link', (
      tester,
    ) async {
      await pumpApp(tester, FakeAuthRepository());
      await tester.tap(find.text('Have an invite link?'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'ezsplit://register?token=%C0%AF&email_address=a@b.c',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text("That isn't an ezsplit invite link"), findsOneWidget);
    });
  });

  group('Forgot password', () {
    testWidgets('sends the link and shows the inbox card', (tester) async {
      final repo = FakeAuthRepository();
      await pumpApp(tester, repo);
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.text('Reset password'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'neha@gmail.com');
      await tester.pump();
      await tester.tap(find.text('Send link'));
      await tester.pumpAndSettle();

      expect(repo.resets, ['neha@gmail.com']);
      expect(find.text('Check your inbox.'), findsOneWidget);
    });
  });

  group('Accept invite', () {
    Future<FakeAuthRepository> openInvite(WidgetTester tester) async {
      final repo = FakeAuthRepository();
      final c = await pumpApp(tester, repo);
      routerOf(c).go('/invite?token=abc&email=neha@gmail.com');
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('shows the email locked and every field', (tester) async {
      await openInvite(tester);
      expect(find.text('neha@gmail.com'), findsOneWidget);
      final email = tester.widget<TextField>(
        find.widgetWithText(TextField, 'neha@gmail.com'),
      );
      expect(email.readOnly, isTrue);
      for (final label in [
        'First name',
        'Last name',
        'Phone',
        'Date of birth',
        'Set a password',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('a 5 character password shows an error and does not submit', (
      tester,
    ) async {
      final repo = await openInvite(tester);
      await tester.enterText(find.byType(TextField).at(5), '12345');
      await tester.ensureVisible(find.text('Join ezsplit'));
      await tester.tap(find.text('Join ezsplit'));
      await tester.pumpAndSettle();
      expect(find.text('Use at least 6 characters'), findsOneWidget);
      expect(repo.invites, isEmpty);
    });

    testWidgets('submits the form and lands on Home', (tester) async {
      final repo = await openInvite(tester);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), 'Neha');
      await tester.enterText(fields.at(2), 'Kapoor');
      await tester.enterText(fields.at(3), '9876543210');
      await tester.ensureVisible(fields.at(4));
      await tester.tap(fields.at(4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(fields.at(5), 'secret1');
      await tester.ensureVisible(find.text('Join ezsplit'));
      await tester.tap(find.text('Join ezsplit'));
      await tester.pumpAndSettle();

      expect(repo.invites, hasLength(1));
      expect(repo.invites.single['token'], 'abc');
      expect(repo.invites.single['email'], 'neha@gmail.com');
      expect(repo.invites.single['phone'], '9876543210');
      expect(repo.invites.single['dob'], isA<DateTime>());
      expect(find.text('Home'), findsWidgets);
    });

    testWidgets('a QR invite asks for the email and submits what was typed', (
      tester,
    ) async {
      final repo = FakeAuthRepository();
      final c = await pumpApp(tester, repo);
      routerOf(c).go('/invite?token=qr1');
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      expect(tester.widget<TextField>(fields.at(0)).readOnly, isFalse);
      await tester.enterText(fields.at(1), 'Sam');
      await tester.enterText(fields.at(2), 'Rao');
      await tester.enterText(fields.at(3), '9876543210');
      await tester.ensureVisible(fields.at(4));
      await tester.tap(fields.at(4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(fields.at(5), 'secret1');
      await tester.ensureVisible(find.text('Join ezsplit'));
      await tester.tap(find.text('Join ezsplit'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email'), findsOneWidget);
      expect(repo.invites, isEmpty);

      await tester.ensureVisible(fields.at(0));
      await tester.enterText(fields.at(0), ' sam@example.com ');
      await tester.pump();
      await tester.ensureVisible(find.text('Join ezsplit'));
      await tester.pump();
      await tester.tap(find.text('Join ezsplit'));
      await tester.pumpAndSettle();

      expect(repo.invites, hasLength(1));
      expect(repo.invites.single['token'], 'qr1');
      expect(repo.invites.single['email'], 'sam@example.com');
      expect(find.text('Home'), findsWidgets);
    });
  });
}
