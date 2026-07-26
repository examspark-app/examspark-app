# Founder — Web + bell notifications (Jul 26, 2026)

**Intent:** Save-audio server + R2 meter **cancelled**. Settings theme/language **pending**. Notifications work on **Chrome web** + red badge; desktop tray when you open another website (Sonaxia tab still open).

## What you get

| Surface | Behavior |
|---------|----------|
| Home 🔔 | **Red number badge** for unread |
| Bell list | Same in-app notifications |
| Chrome desktop | OS tray popup when Sonaxia tab is **open but hidden** (you switched to Gmail etc.) |
| Settings | Study / Group toggles + **Enable desktop browser alerts** |
| Save original audio | **Removed** from Settings |
| R2 Storage MB | **Not building** (cancelled) |

**Limit:** If you **fully close** the Sonaxia tab, tray alerts stop (needs Firebase Web Push later). Keep Sonaxia open in a background tab.

## Manual setup

1. Flutter **hot restart** (Chrome)  
2. Backend must run (`:8000`) — notifications API  
3. Profile → **Settings** → **Enable** under Desktop browser alerts → Chrome Allow  
4. **No new SQL · no new .env** for this slice  

(If notifications table never created: run `teacher_coupon_migration.sql` once — older step.)

## Smoke

1. Home → bell shows number when unread exists  
2. Settings → Enable desktop alerts → Allow  
3. Keep Sonaxia on `localhost:8080`, open **another tab** (Google)  
4. Teacher shares to your group (or wait for poll ~25s)  
5. Expect: Chrome OS notification while on the other tab  
6. Return to Sonaxia → badge updates; open bell → mark read → badge clears  

## Cancelled / pending queue

| Item | Status |
|------|--------|
| Save-audio server | **Cancelled** |
| R2 meter | **Cancelled** |
| Settings theme / language / about | **Pending** → `start settings extras` |
| Full FCM phone lock screen | Separate → `start FCM` (Android) |

## Files

- `notification_inbox_controller.dart` · `web_browser_notify*.dart`
- `app_top_bar.dart` · `home_tab.dart` · `settings_screen.dart` · `auth_gate.dart`
