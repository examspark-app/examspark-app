# Founder — Firebase Cloud Messaging (FULL push)

> Goal: Teacher posts → student sees notification on **phone lock screen**, **phone home tray**, **Groups list** (unread badge), and **Home bell**. Tap opens that group.

> **Important (Jul 23, 2026):** Google discontinued the Legacy Cloud Messaging **Server key** API. ExamSpark now uses **FCM HTTP v1** with a **Service Account JSON** file.

## What code already does

| Surface | Status |
|---------|--------|
| Groups list unread badge + preview | App code ready (after SQL) |
| Home bell in-app list | Ready |
| Backend FCM send on share | Ready when `FIREBASE_SERVICE_ACCOUNT_JSON` set |
| Flutter FCM listen + open group | Ready when `google-services.json` present |
| Lock / home screen system push | Needs Firebase project + Android build |

Chrome web: in-app only (lock-screen push needs **Android phone/emulator**).

---

## Steps (do in order)

### A) SQL (if not done)

Run `teacher_coupon_migration.sql` (creates `notifications` + `device_tokens`).

### B) Firebase Console — Android app + google-services.json

1. [Firebase Console](https://console.firebase.google.com/) → Create / open ExamSpark project  
2. Add **Android** app  
3. Package name must be: `com.sonialabs.sonaxia`  
   (same as `android/app/build.gradle.kts` → `applicationId`)  
4. Download **`google-services.json`**  
5. Copy file to:  
   `examspark_frontend/android/app/google-services.json`

### C) Service Account JSON (backend send auth — HTTP v1)

1. Firebase Console → gear **Project settings** → **Service accounts** tab  
2. Click **Generate new private key** → confirm → downloads a `.json` file  
3. Create folder (once):

```powershell
mkdir "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend\secrets"
```

4. Move/rename the downloaded file to:

```text
C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend\secrets\firebase-service-account.json
```

5. Open `examspark_backend/.env` and set:

```env
FIREBASE_SERVICE_ACCOUNT_JSON=C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend\secrets\firebase-service-account.json
```

(Optional) If the JSON has no `project_id`, also set `FIREBASE_PROJECT_ID=your-firebase-project-id`.

**Do not** use `FIREBASE_SERVER_KEY` anymore — that Legacy API is dead.

**Security:** Never commit the service-account JSON to GitHub. Folder `examspark_backend/secrets/` is gitignored.

### D) Restart backend

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### E) Flutter packages + Android rebuild

```powershell
cd "C:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_frontend"
flutter pub get
flutter run -d <your-android-device-or-emulator>
```

(Do **not** expect lock-screen push on Chrome alone.)

### F) Smoke

1. Student logged in on Android (allow notifications)  
2. Teacher shares a lecture to that group  
3. Expect:  
   - Lock screen / notification tray message  
   - Groups list: green unread badge + preview line  
   - Tap notification → opens **that** group  
   - Home bell also shows the same event  

---

## Verify checkpoint

| Check | OK? |
|-------|-----|
| `google-services.json` in `android/app/` | |
| `FIREBASE_SERVICE_ACCOUNT_JSON` points to real JSON file | |
| Backend restarts without FCM auth errors | |
| Device got system notification | |
| Groups list badge cleared after opening group | |

If Firebase not set up yet: app still runs; FCM soft-skips; in-app Groups + Home bell still work after SQL.

## iOS

Later (~3 months). Android first.
