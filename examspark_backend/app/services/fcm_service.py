"""FCM HTTP v1 push — Service Account JSON (not Legacy server key).

Never raises to callers; logs and returns. Founder guide: FOUNDER_FCM_SETUP.md

Auth: OAuth2 access token from Firebase service-account JSON
  (Console → Project Settings → Service Accounts → Generate New Private Key).

Env:
  FIREBASE_SERVICE_ACCOUNT_JSON = path to JSON file OR raw JSON string
  FIREBASE_PROJECT_ID           = optional override (else read from JSON)
"""
from __future__ import annotations

import json
import logging
import os
import threading
from typing import Any

import httpx

from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)

_FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

_cred_lock = threading.Lock()
_cached_creds: Any = None
_cached_project_id: str | None = None


def _service_account_raw() -> str:
    return (os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON") or "").strip()


def fcm_configured() -> bool:
    if _service_account_raw():
        return True
    # Legacy key is discontinued — warn once if still present, never send with it.
    if (os.getenv("FIREBASE_SERVER_KEY") or "").strip():
        logger.warning(
            "FIREBASE_SERVER_KEY is set but Legacy FCM API is discontinued. "
            "Use FIREBASE_SERVICE_ACCOUNT_JSON (path to service-account JSON) instead — "
            "see FOUNDER_FCM_SETUP.md"
        )
    return False


def _load_service_account_info() -> dict[str, Any]:
    raw = _service_account_raw()
    if not raw:
        raise RuntimeError("FIREBASE_SERVICE_ACCOUNT_JSON not set")
    if os.path.isfile(raw):
        with open(raw, encoding="utf-8") as f:
            return json.load(f)
    return json.loads(raw)


def _get_access_token_and_project() -> tuple[str, str]:
    """Return (bearer_token, project_id), refreshing credentials as needed."""
    global _cached_creds, _cached_project_id

    from google.auth.transport.requests import Request
    from google.oauth2 import service_account

    with _cred_lock:
        if _cached_creds is None:
            info = _load_service_account_info()
            _cached_creds = service_account.Credentials.from_service_account_info(
                info,
                scopes=[_FCM_SCOPE],
            )
            override = (os.getenv("FIREBASE_PROJECT_ID") or "").strip()
            _cached_project_id = override or str(info.get("project_id") or "").strip()
            if not _cached_project_id:
                raise RuntimeError(
                    "Firebase project_id missing — set FIREBASE_PROJECT_ID "
                    "or use a service-account JSON that includes project_id"
                )

        if not _cached_creds.valid:
            _cached_creds.refresh(Request())

        token = _cached_creds.token
        if not token or not _cached_project_id:
            raise RuntimeError("Failed to obtain FCM access token / project_id")
        return str(token), str(_cached_project_id)


def send_push_to_users(
    *,
    user_ids: list[str],
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> int:
    if not user_ids or not fcm_configured():
        return 0

    db = get_supabase_admin()
    try:
        res = (
            db.table("device_tokens")
            .select("token")
            .in_("user_id", user_ids)
            .execute()
        )
        tokens = [r["token"] for r in (res.data or []) if r.get("token")]
    except Exception as e:  # noqa: BLE001
        logger.warning("device_tokens read failed: %s", e)
        return 0

    if not tokens:
        return 0

    try:
        access_token, project_id = _get_access_token_and_project()
    except Exception as e:  # noqa: BLE001
        logger.warning("FCM auth failed: %s", e)
        return 0

    payload_data = {k: str(v) for k, v in (data or {}).items()}
    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json; charset=UTF-8",
    }

    sent = 0
    with httpx.Client(timeout=15.0) as client:
        for device_token in tokens:
            message: dict[str, Any] = {
                "message": {
                    "token": device_token,
                    "notification": {
                        "title": title,
                        "body": body,
                    },
                    "data": payload_data,
                    "android": {
                        "priority": "HIGH",
                        "notification": {
                            "sound": "default",
                            "click_action": "FLUTTER_NOTIFICATION_CLICK",
                        },
                    },
                    "apns": {
                        "payload": {
                            "aps": {
                                "sound": "default",
                            }
                        }
                    },
                }
            }
            try:
                r = client.post(
                    url,
                    headers=headers,
                    content=json.dumps(message),
                )
                if r.status_code < 300:
                    sent += 1
                else:
                    logger.warning(
                        "FCM v1 send failed %s: %s", r.status_code, r.text[:300]
                    )
            except Exception as e:  # noqa: BLE001
                logger.warning("FCM v1 send error: %s", e)
    return sent
