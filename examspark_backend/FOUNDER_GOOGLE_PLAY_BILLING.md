# Sonaxia — Full Google Play Billing Guide (Founder)

**Audience:** Non-developer founder  
**Goal:** Real Android purchases (Google’s payment sheet) → server verifies → plan/credits unlock  
**Live public Store NOT required** — Internal testing is enough for first real tests  

**Related:**  
- Package ID: [`FOUNDER_PACKAGE_RENAME_SONAXIA.md`](FOUNDER_PACKAGE_RENAME_SONAXIA.md)  
- Dev mock (+50 credits, no Google): [`FOUNDER_MOCK_PURCHASE_TESTING.md`](FOUNDER_MOCK_PURCHASE_TESTING.md)  
- Web payments (Razorpay): [`FOUNDER_RAZORPAY_SESSION6.md`](FOUNDER_RAZORPAY_SESSION6.md)  

---

## 0) Big picture (30 seconds)

```text
You (Sonaxia app UI)
  → Plan / pack button
  → Google Play payment sheet (Google designs this — you cannot restyle it)
  → Purchase token
  → Our FastAPI server checks with Google
  → Credits / plan unlocked in Supabase
```

| Where | Who owns the UI |
|-------|-----------------|
| Plans, prices, Buy button, success message | **You + ExamSpark** |
| Card / UPI / Google Play pay sheet | **Google** |
| Chrome web browser buy | **Razorpay** (not Google Play) |

**Chrome / localhost:8080 = Google Play nahi.** Real Google = **Android phone** + Play install.

---

## 1) Your PC status right now (check this first)

Open `examspark_backend/.env` and confirm:

| Variable | Needed for real Play? | Typical status |
|----------|----------------------|----------------|
| `GOOGLE_PLAY_PACKAGE_NAME=com.sonialabs.sonaxia` | Yes | Often already SET |
| `GOOGLE_PLAY_LICENSE_KEY=...` | Nice to have / future | Often already SET |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=...` | **Yes — required** | Often **MISSING** |
| `IS_TESTING=true` | Mock only | Must become **`false`** before real Play |

Also Flutter: `examspark_frontend/.env`

| Variable | Note |
|----------|------|
| `IS_TESTING` | Must be **`false`** for real Play |
| `FASTAPI_BASE_URL` | Phone needs PC LAN IP, **not** `localhost` |

Example phone API URL:

```env
FASTAPI_BASE_URL=http://192.168.x.x:8000
```

(Your Wi‑Fi IP — see Step 8.)

---

## 2) Checklist — do in this order

- [ ] **A.** Play Console app with package `com.sonialabs.sonaxia`
- [ ] **B.** Firebase `google-services.json` for same package (push/login)
- [ ] **C.** Create all product IDs (exact spelling)
- [ ] **D.** Build AAB + upload Internal testing + install on phone
- [ ] **E.** Service account JSON + link in Play Console
- [ ] **F.** Paste paths in `.env` + set `IS_TESTING=false`
- [ ] **G.** License testers (your Gmail)
- [ ] **H.** Smoke buy on phone
- [ ] **I.** (Later) Refund / RTDN webhook

Do **not** skip E — without service account, Google sheet may open but **credits will not unlock** (server cannot verify).

---

## 3) Product IDs (must match 100%)

Create these **exact** IDs in Play Console (code uses them):

### Subscriptions

| App plan | Play product ID | Type |
|----------|-----------------|------|
| ₹199 | `examspark_plan_199` | Subscription |
| ₹299 (if used) | `examspark_plan_299` | Subscription |
| ₹499 | `examspark_plan_499` | Subscription |
| ₹999 | `examspark_plan_999` | Subscription |
| Teacher | `examspark_plan_teacher` | Subscription |

### One-time credit packs (consumable)

| Pack | Play product ID |
|------|-----------------|
| 100 credits | `examspark_pack_100` |
| 500 | `examspark_pack_500` |
| 1000 | `examspark_pack_1000` |
| 5000 | `examspark_pack_5000` |
| 10000 | `examspark_pack_10000` |

**Verify:** spelling, underscores, no spaces. Wrong ID = buy fails or “product not found”.

Package / applicationId everywhere:

```text
com.sonialabs.sonaxia
```

---

## Step A — Play Console app

1. Open [Google Play Console](https://play.google.com/console) (paid developer account).
2. **Create app** (or open existing).
3. App name can be **Sonaxia**.
4. When asked for package name, use: **`com.sonialabs.sonaxia`**  
   - If an old app used a different package, you **cannot** “rename” it — create a **new** app listing.
5. Complete basic store listing drafts if Console asks (can stay draft).
6. You do **not** need **Production / Live** yet.

**Verify:** App settings / dashboard shows package `com.sonialabs.sonaxia`.

---

## Step B — Firebase (same package)

Push / some login pieces need matching Firebase Android app.

1. [Firebase Console](https://console.firebase.google.com/) → your project  
2. **Add Android app** → package **`com.sonialabs.sonaxia`**  
3. Download **new** `google-services.json`  
4. Replace:

```text
examspark_frontend/android/app/google-services.json
```

**Verify:** open JSON → `"package_name": "com.sonialabs.sonaxia"`

Full note: [`FOUNDER_PACKAGE_RENAME_SONAXIA.md`](FOUNDER_PACKAGE_RENAME_SONAXIA.md)

---

## Step C — Create products in Play Console

1. Open your Sonaxia app in Play Console.  
2. Left menu → **Monetize** (or **Monetization**) → **Products**.

### Subscriptions

1. **Subscriptions** → Create subscription.  
2. Product ID = e.g. `examspark_plan_199` (cannot change later — type carefully).  
3. Add base plan / price in INR (₹199 etc.).  
4. Activate / make available for testers.  
5. Repeat for all subscription IDs in the table.

### Credit packs

1. **In-app products** (one-time) → Create.  
2. Product ID = e.g. `examspark_pack_100`.  
3. Type: **Consumable** (or one-time that can be bought again).  
4. Set price. Activate.  
5. Repeat for all packs.

**Verify:** every ID matches the table exactly.  
**Tip:** keep a notepad list and tick each ID after create.

---

## Step D — Internal testing build (AAB) on phone

Billing usually needs at least one uploaded build.

### D1 — Build App Bundle on PC

Open PowerShell:

```powershell
cd "c:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_frontend"
flutter clean
flutter pub get
flutter build appbundle
```

**Verify:** file appears roughly at:

```text
examspark_frontend\build\app\outputs\bundle\release\app-release.aab
```

If build asks for signing / keystore and fails: stop and message AI **`play signing help`** (signing setup is a separate mini-guide).

### D2 — Upload Internal testing

1. Play Console → **Testing** → **Internal testing**  
2. **Create new release** → upload the `.aab`  
3. Add release notes (e.g. “Internal billing test”) → Review → Start rollout to Internal testing  

### D3 — Become a tester + install

1. Internal testing → **Testers** → create email list → add your Gmail  
2. Copy **opt-in link** → open on the **phone** (same Gmail) → Accept  
3. Install Sonaxia from the testing link / Play Store testing page  

**Verify:** phone Settings → Apps → Sonaxia → package should be `com.sonialabs.sonaxia`  
Uninstall any old debug build with a different package first.

---

## Step E — Service account (server can talk to Google)

This is the missing piece for most founders.

### E1 — Google Cloud

1. Open [Google Cloud Console](https://console.cloud.google.com/) with the **same Google account** as Play.  
2. Select / create a Cloud project.  
3. **APIs & Services** → **Enable APIs** → enable **Google Play Android Developer API**.  

### E2 — Create service account + JSON key

1. **IAM & Admin** → **Service accounts** → **Create**  
2. Name e.g. `sonaxia-play-verify`  
3. Create → open the account → **Keys** → **Add key** → **JSON** → download  
4. Save on PC in a safe folder (example):

```text
C:\secrets\sonaxia-play.json
```

**Never** commit this file to Git / never paste full JSON in chat.

### E3 — Link service account to Play Console

1. Play Console → **Users and permissions** (or Setup → API access)  
2. Invite / link the service account email (`...@...iam.gserviceaccount.com`)  
3. Permissions needed (wording varies): view app information, **view financial data**, manage orders / reply to reviews as required by Console for purchase API  

**Verify:** service account appears under Play users with access to your app.

---

## Step F — `.env` for real Play (turn mock OFF)

### Backend — `examspark_backend/.env`

```env
GOOGLE_PLAY_PACKAGE_NAME=com.sonialabs.sonaxia
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=C:\secrets\sonaxia-play.json
IS_TESTING=false
```

(`GOOGLE_PLAY_LICENSE_KEY` can stay as-is.)

### Flutter — `examspark_frontend/.env`

```env
IS_TESTING=false
FASTAPI_BASE_URL=http://YOUR_PC_LAN_IP:8000
```

### Restart FastAPI

```powershell
cd "c:\Users\MIRZA COMPUTER\Documents\ExamSpark-Project\examspark_backend"
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**Verify on PC browser:** open `http://localhost:8000/docs` (or `/`) — API responds.

---

## Step G — License testers (sandbox-style buys)

1. Play Console → **Settings** → **License testing**  
2. Add the Gmail used on the test phone  
3. Those accounts get **license test** purchases (follow Console text — often not full real charge)

**Verify:** your Gmail is listed under license testers.

---

## Step H — Smoke test on phone (real Google sheet)

### H1 — Phone can reach your PC API

On the phone (same Wi‑Fi as PC), open Chrome:

```text
http://YOUR_PC_LAN_IP:8000/
```

If it does not load: Windows Firewall allow Python / port 8000, or fix IP.

Find PC IP (PowerShell):

```powershell
ipconfig
```

Use **IPv4 Address** under your Wi‑Fi adapter (example `192.168.1.10`).

### H2 — Buy flow

1. Open Sonaxia from **Internal testing** install (not random old APK if possible).  
2. Log in with your normal account.  
3. Profile → Subscription → buy **₹199** (or a small pack).  
4. **Expected:** Google Play payment sheet opens (Google UI).  
5. Complete test purchase.  
6. **Expected:** app shows success; plan/credits update after server verify.

### H3 — Confirm in Play Console

Play Console → **Order management** (or Monetize → orders) → see order for your product ID.

### If it fails

| Symptom | Likely cause |
|---------|----------------|
| No Google sheet / product not found | Product ID mismatch or app not on Internal testing |
| Sheet OK but no credits | Service account missing / no Play API permission / `IS_TESTING` still true on one side |
| Network / API error | `FASTAPI_BASE_URL` still `localhost` on phone |
| Wrong package | Old APK / Firebase / Console package mismatch |

Check FastAPI terminal logs when you tap Buy.

---

## Step I — Refund awareness (later)

- Money refunds happen in **Play Console**, not inside Sonaxia UI.  
- After refund, ExamSpark should remove paid access (webhook / RTDN when configured).  
- Endpoint (later): `POST /api/v1/payments/webhooks/google-play`  
- Policy doc: [`REFUND_POLICY_AND_PROCESS.md`](../REFUND_POLICY_AND_PROCESS.md)

You can finish first successful **test buy** before RTDN.

---

## Mock vs Real (do not confuse)

| Mode | `IS_TESTING` | Device | What happens |
|------|--------------|--------|--------------|
| Dev mock | `true` | Chrome or Android | No Google sheet; **+50 credits** via FastAPI |
| Real Google | `false` | Android Internal build | Google sheet → server verify → real plan/pack credits |

After mock testing, always set **`IS_TESTING=false`** before phone Play smoke.

Guide for mock: [`FOUNDER_MOCK_PURCHASE_TESTING.md`](FOUNDER_MOCK_PURCHASE_TESTING.md)

---

## What AI can do vs what only you can do

| Task | Who |
|------|-----|
| Play Console create app / products / upload AAB | **You** (Google login) |
| Firebase new `google-services.json` | **You** |
| Service account JSON download | **You** |
| Paste `.env` paths / restart commands | You (or ask AI after files exist) |
| Fix code / product ID mapping bugs | **AI** (after you say `start …`) |
| Fake “Play is live” without Console | **Nobody** — not allowed |

---

## Suggested work sessions (bite-size)

1. **Today:** Steps A + C (Console app + product IDs)  
2. **Next:** Step E (service account JSON) → message AI: `service account ready`  
3. **Then:** Step D (AAB + Internal install)  
4. **Then:** Step F + G + H (env off mock + phone buy)

When stuck, reply with the **step letter** (A–H) and the exact error screen text / photo description.

---

## Rollback

1. Set `IS_TESTING=true` again if you only want mock.  
2. Or clear `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` → verify fails closed (no fake success).  
3. Uninstall Internal test app from phone if needed.

---

## Short “done” definition

Real Google setup is **done** only when:

1. Internal testing install on phone works  
2. Google pay sheet opens for a real product ID  
3. FastAPI verify succeeds  
4. Your account shows plan or credits correctly  

Until then: mock on Web is OK for UI/credits experiments — it is **not** Play Billing complete.
