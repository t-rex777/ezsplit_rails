# ezsplit

ezsplit splits shared expenses between friends. Add a group, log what you paid, and the app tells everyone who owes whom.

This repo holds two packages:

| Folder | What it is | Stack |
|---|---|---|
| [`api/`](api) | The JSON API and database | Rails 8, SQLite, RSpec |
| [`android/`](android) | The phone app | Flutter 3.47, Riverpod, Dio |

## Architecture

```mermaid
flowchart LR
  subgraph Phone["Phone app (android/)"]
    UI["screens/ and widgets/<br/>what you see"]
    State["state/<br/>Riverpod providers"]
    Data["data/<br/>repositories + ApiClient (Dio)"]
    Domain["domain/<br/>money, splits, settle plan"]
    UI --> State --> Data
    State --> Domain
  end

  subgraph Server["Rails API (api/)"]
    Auth["Authentication concern<br/>session cookie"]
    Ctrl["Controllers<br/>groups, expenses, balances,<br/>settlements, invitations, me"]
    Ser["Serializers<br/>JSON:API"]
    Calc["BalanceCalculator"]
    DB[("SQLite")]
    Auth --> Ctrl --> Ser
    Ctrl --> Calc --> DB
    Ctrl --> DB
  end

  Mail["Mailer<br/>invites, friend requests"]
  Data -- "HTTPS + session cookie<br/>JSON:API" --> Auth
  Ctrl --> Mail
```

How a request flows:

1. A screen reads a Riverpod provider in `android/lib/state/`.
2. The provider calls a repository in `android/lib/data/`. The repository sends the request through `ApiClient`, which keeps the session cookie.
3. Rails checks the cookie in `api/app/controllers/concerns/authentication.rb`. Then the controller loads only the data the signed-in user may see.
4. A serializer returns JSON:API. The app parses it into models in `android/lib/data/models.dart`.

Rules the API enforces:

- A group can only contain friends of the person adding them.
- Phone and date of birth are only sent to their owner.
- Inviting an existing user sends a friend request. They must accept before they become a friend.

## How it works

Screenshots from an Android phone.

| Home | Groups | A group |
|---|---|---|
| ![Home](docs/screenshots/01-home.png) | ![Groups](docs/screenshots/02-groups.png) | ![A group](docs/screenshots/03-group.png) |

| Add an expense | Balances | Profile |
|---|---|---|
| ![Add an expense](docs/screenshots/04-add-expense.png) | ![Balances](docs/screenshots/05-balances.png) | ![Profile](docs/screenshots/06-profile.png) |

1. **Home** shows your share this month, what you owe, what you are owed, and spending by category.
2. **Groups** lists your groups. Filter to groups that owe you or that you owe, and see friend requests waiting for you.
3. **A group** shows its expenses by date, with what you lent or owe on each.
4. **Add an expense.** Split it equally, by percentage, or by exact amounts. The app shows each share before you save.
5. **Balances** shows who owes whom and the fewest payments that settle the group. Tap **Settle up** to record one.
6. **Profile** holds your details, your categories, the light or dark theme, and log out. You stay signed in after a restart until you log out.

## Run it locally

Start the API on port 3100:

```bash
cd api
mise exec ruby@3.2.2 -- bin/rails db:prepare
mise exec ruby@3.2.2 -- bin/rails server -p 3100
```

Run the app on a plugged-in Android phone:

```bash
adb reverse tcp:3100 tcp:3100
```

```bash
cd android && flutter run
```

The app calls `http://localhost:3100` by default. Change it with `--dart-define=API_BASE_URL=...`. Release builds refuse any address that is not `https`.

### Test on phones over Wi-Fi

Run the API on your Mac so other devices on the same Wi-Fi can reach it. Find the Mac's address with `ipconfig getifaddr en0`; the examples use `192.168.1.4`.

```bash
cd api && APP_HOST=192.168.1.4 APP_PORT=3100 mise exec ruby@3.2.2 -- bin/rails server -p 3100 -b 0.0.0.0
```

`APP_HOST` and `APP_PORT` set the address used in invite emails. Then build a LAN APK, which may use `http` to a private address only:

```bash
cd android && EZSPLIT_LAN_HTTP=1 flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.4:3100 --dart-define=ALLOW_LAN_HTTP=true
```

The session cookie travels unencrypted over the Wi-Fi in this build, so use it only on a network you trust. If the Mac's address changes, rebuild. Normal release builds stay https-only.

## Tests

```bash
cd api && mise exec ruby@3.2.2 -- bundle exec rspec
```

```bash
cd android && flutter test
```

## Releases

Every merge into `dev` that changes `android/` builds a signed APK. The workflow `.github/workflows/android-apk.yml` attaches it to a GitHub pre-release named `dev-<run number>`.

To install it: open the repo's **Releases** page on your phone, download the newest `ezsplit-dev-*.apk`, and open it. Each build has a higher build number, so it installs over the last one.

### One-time setup

The workflow needs one repository variable and four secrets. Without them the build stops with an error that names the missing one.

1. Make a signing key. Keep the file and passwords somewhere safe; losing them means users must uninstall to update.

   ```bash
   keytool -genkeypair -keystore ezsplit-release.jks -alias ezsplit -keyalg RSA -keysize 2048 -validity 10000
   ```

2. In GitHub, open **Settings → Secrets and variables → Actions** and add:

   | Name | Kind | Value |
   |---|---|---|
   | `API_BASE_URL` | Variable | The live API address, starting with `https://` |
   | `ANDROID_KEYSTORE_BASE64` | Secret | Output of `base64 -i ezsplit-release.jks` |
   | `ANDROID_KEYSTORE_PASSWORD` | Secret | The keystore password |
   | `ANDROID_KEY_ALIAS` | Secret | `ezsplit` |
   | `ANDROID_KEY_PASSWORD` | Secret | The key password |

The API workflows (RSpec, Rubocop, Brakeman, Fly deploy) run only when `api/` changes.
