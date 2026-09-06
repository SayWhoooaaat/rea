# Rank Everything Always (REA)

A tier-list app for Android. Make a list, drop in images or text, drag things
into S/A/B/C/D rows, export the result as an image.

Everything is stored locally on the device — there is no backend, no account,
and no analytics. Tier lists live in `shared_preferences` and images in the
app's own directory.

## Features

- Create, rename, hide, reorder and delete tier lists
- Custom tiers: add, rename, recolor, reorder, delete rows
- Add items from the camera, the device gallery, an in-app image search, or plain text
- Crop and zoom items to frame them how you want
- Cover photos for each list
- Export a finished list as an image, and share it
- Backup and restore all lists to a `.zip` file
- Optional password to hide lists

## Status

**Unmaintained.** This was a personal project, built largely by vibe coding in
2024. It works and it shipped on Google Play, but I am no longer actively
developing it. It is open source so it doesn't die — forks and maintainers are
welcome.

Fair warning: the code is a hobby project, not a reference architecture. Most
of the app lives in two large widget files. There are no meaningful tests.

### Known work needed

The app currently targets API 35. Google Play has required API 36 (Android 16)
for updates since 31 August 2026, so **the Play listing can no longer be
updated until this is done**. The app itself still runs fine. Bumping it means:

- Upgrade `image_cropper` from 9.1.0 to 12.x. Version 10 moves to uCrop 2.2.11
  with proper edge-to-edge support and `compileSdk 36`, which removes the
  original reason for staying on 35. It also replaces `statusBarColor` with
  `statusBarLight` / `navBarLight`, and 11+ needs a recent Flutter.
- Drop the `android:windowOptOutEdgeToEdgeEnforcement` workaround in
  `android/app/src/main/res/values/styles.xml`. Targeting API 36 ignores it —
  Google removed the opt-out.
- Handle window insets across the app. Targeting 36 forces edge-to-edge, and
  right now there is a single `SafeArea` in the whole codebase, so content will
  draw behind the status and navigation bars until this is addressed.

## Building

Requires the Flutter SDK and a JDK 17 toolchain.

```bash
flutter pub get
flutter run
```

Release builds are signed with an upload keystore that is deliberately not in
this repository. Without it, release builds fall back to debug signing and
still work:

```bash
flutter build apk --release
```

To sign with your own key, create `android/key.properties`:

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=…
keyAlias=…
keyPassword=…
```

That file and `*.jks` are both gitignored — keep them out of version control.

## License

[MIT](LICENSE)
