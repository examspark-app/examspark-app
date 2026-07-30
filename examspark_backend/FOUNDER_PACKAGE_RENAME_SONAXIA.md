# Founder — Package / Bundle ID rename → `com.sonialabs.sonaxia`

**Coded Jul 24, 2026** (Android + iOS). Display name left as-is (Sonaxia in app UI).

## What changed in code

| Place | New value |
|-------|-----------|
| Android `applicationId` + `namespace` | `com.sonialabs.sonaxia` |
| Android `MainActivity` package | `com.sonialabs.sonaxia` |
| iOS `PRODUCT_BUNDLE_IDENTIFIER` | `com.sonialabs.sonaxia` |
| iOS tests | `com.sonialabs.sonaxia.RunnerTests` |
| `google-services.json` → `package_name` | `com.sonialabs.sonaxia` (must match Firebase) |

Canonical Flutter app: `examspark_frontend/` only.

## Manual setup (required — Firebase)

Old Firebase Android app was `com.sonia.sonialabs`. New package **will not match** until you add / switch the app in Firebase.

### 1. Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com/) → project **sonia-ai-8141d** (or your Sonia project)  
2. **Add app** → Android  
3. Package name: **`com.sonialabs.sonaxia`** (exact)  
4. Download **new** `google-services.json`  
5. Replace file:  
   `examspark_frontend/android/app/google-services.json`  
6. (Optional) remove or ignore the old Android app `com.sonia.sonialabs`

**Verify:** open the new JSON → `"package_name": "com.sonialabs.sonaxia"`

### 2. Backend `.env` (Play Billing)

In `examspark_backend/.env` set (or update):

```env
GOOGLE_PLAY_PACKAGE_NAME=com.sonialabs.sonaxia
```

(Config reads **`GOOGLE_PLAY_PACKAGE_NAME`**, not `GOOGLE_PLAY_PACKAGE`.)

Restart FastAPI after change.

### 3. Uninstall old debug app (phone)

Old package `com.sonia.sonialabs` and new `com.sonialabs.sonaxia` are **different apps**.  
Uninstall old Sonaxia/ExamSpark debug build, then:

```text
cd examspark_frontend
flutter clean
flutter pub get
flutter run
```

### 4. iOS

Bundle ID is already `com.sonialabs.sonaxia` in Xcode project.  
When you add Firebase iOS later: create iOS app with the **same** bundle ID and add `GoogleService-Info.plist`.

### 5. Google Play Console (when publishing)

Create / use Play app with package **`com.sonialabs.sonaxia`**.  
Cannot update an existing Play listing that used a different package.

## Smoke

1. `flutter run` on Android installs as `com.sonialabs.sonaxia`  
2. App opens (Sonaxia UI unchanged)  
3. After new `google-services.json`: login → FCM token register (no Firebase package mismatch errors)

## Rollback

Revert git changes to `build.gradle.kts`, `MainActivity` path, iOS `project.pbxproj`, `google-services.json`, and restore old Firebase JSON if needed.
