# Al-Qur’an Companion — Flutter starter

This is an **editable source project**, not an installable APK. It has a functional online Surah reader, dynamic English/Yoruba translation edition discovery (subject to the provider's catalogue), reciter selection, verse-level audio follow/highlighting, automatic scrolling, repetition, and saved last Surah.

## Build
1. Install Flutter SDK, Android SDK and Android Studio; run `flutter doctor` and resolve Android issues.
2. In this directory run `flutter create --platforms android .` to generate standard Android platform files.
3. In `android/app/src/main/AndroidManifest.xml`, add `<uses-permission android:name="android.permission.INTERNET" />` immediately under `<manifest>` and before `<application>`.
4. Run `flutter pub get`, `flutter run` to test on a connected Android device, and `flutter build apk --release` to build.
5. APK output: `build/app/outputs/flutter-apk/app-release.apk`. Configure release signing before publishing to Play Store.

## Content and correctness notes
- Content is requested at runtime from AlQuran Cloud API (https://alquran.cloud/api). Verify provider availability, attribution, permitted reuse and each edition's licensing before distribution.
- The initial Arabic text uses `ar.alafasy` edition for verse correspondence; this is NOT a verified Tajweed-color markup dataset. Do not represent it as color-coded Tajweed.
- The app synchronizes **verses** by waiting for each verse's actual audio to finish. It does NOT yet offer word-level timestamps/highlighting; that requires licensed, verified word-alignment data for each reciter.
- Yoruba translation appears in the dropdown only if the live provider edition catalogue returns a Yoruba edition. If not available, add a separately licensed and reviewed Yoruba dataset; do not fabricate translations.
- Font toggle uses device serif/sans-serif fallbacks. For a production app, bundle and verify licensed Uthmani/IndoPak/Naskh fonts and test Arabic combining marks.
- No offline audio download, memorisation tests, Tajweed lessons or multi-translation parallel view is implemented in this starter. These are future milestones, not shipping claims.
- Review all Arabic text, verse boundaries, translations, recitation rights and Tajweed rules with qualified reviewers before publication.
