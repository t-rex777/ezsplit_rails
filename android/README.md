# ezsplit mobile

ezsplit is a Splitwise-style app for splitting expenses with friends. This is the Flutter client. It talks to the ezsplit Rails JSON API and keeps its session in a cookie. You join by invite link, create groups, add expenses (equal, percentage or exact splits), see balances, and settle up.

## Prerequisites

- Flutter 3.x with Dart ^3.13.5 (`flutter --version`).
- For iOS: Xcode with an iOS simulator.
- For Android: Android Studio with an emulator.
- The ezsplit Rails backend, on the `feat/mobile-api` branch, running locally.

## Run the Rails backend

The demo seed script is not in this repo. It lives in the project's work folder, outside both repos, at `~/Documents/Cobol/work/analysis/2026-10-27-ezsplit-mobile-api-fixtures/demo_seed.rb`. It only runs in the development environment.

From the root of the Rails backend folder (the checkout that has the mobile API):

```bash
mise exec ruby@3.2.2 -- bin/rails runner ~/Documents/Cobol/work/analysis/2026-10-27-ezsplit-mobile-api-fixtures/demo_seed.rb   # demo data
mise exec ruby@3.2.2 -- bin/rails server -p 3100
```

The demo login is `milisha.demo@example.com` / `password123`. Friends are Riya, Arjun and Neha. There is a pending invite for `sam.demo@example.com`. How the demo data is made is described in `README.md` beside the seed script, in the same work folder.

## Run the app

The API address is set with `--dart-define=API_BASE_URL=...`. The default is `http://localhost:3100`.

iOS simulator:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3100
```

Android emulator (it reaches the host machine at `10.0.2.2`):

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3100
```

## Open an invite link

Invite links use the `ezsplit://register` scheme. Replace the token and email with a real invite.

iOS simulator:

```bash
xcrun simctl openurl booted "ezsplit://register?token=TOKEN&email_address=sam.demo@example.com"
```

Android emulator:

```bash
adb shell am start -a android.intent.action.VIEW -d "ezsplit://register?token=TOKEN&email_address=sam.demo@example.com"
```

## Run the tests

Unit and widget tests. These need no server:

```bash
flutter analyze
flutter test
```

## Live API test

`test/live/live_api_test.dart` uses the real client and repositories against a running server with the demo data. A plain `flutter test` skips it.

```bash
flutter test test/live --run-skipped -t live
```

Optional flags:

- `--dart-define=API_BASE_URL=http://host:port` to use another server.
- `--dart-define=INVITE_TOKEN=...` to also test invite acceptance for `sam.demo@example.com`. An invite token works once, so that test is skipped without it.

The test creates a group named "Live test <timestamp>". The server does not allow deleting a group that has settlements, and the API cannot delete settlements. So each run leaves one settled group behind. Reset the demo data by running the seed again.

## Manual walkthrough

Not yet verified on a device. This Mac has no iOS simulator or Android emulator, so only the live API test has run.

- [ ] 1. Log in.
- [ ] 2. Create a group with one friend.
- [ ] 3. Add an expense of ₹3,000 split by percentage.
- [ ] 4. Check Balances.
- [ ] 5. Settle up.
- [ ] 6. Check that the balance reaches 0.
- [ ] 7. Switch to dark mode.
- [ ] 8. Log out.
- [ ] 9. Open an invite link and join.

Compare each screen with the design canvas.
