"""Verify Phase 5 smoke prerequisites without printing secrets.

Checks:
  1. Backend health (uvicorn on :8000)
  2. Authenticated lecture insert (group_shared_items GRANT applied)
  3. Optional end-to-end JPG process via FastAPI (needs OpenRouter credits)

Usage (from examspark_backend/):
  python scripts/verify_smoke_prereqs.py
  python scripts/verify_smoke_prereqs.py --e2e-image
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx
import jwt
from dotenv import load_dotenv

BACKEND_DIR = Path(__file__).resolve().parents[1]
ROOT = BACKEND_DIR.parent
sys.path.insert(0, str(BACKEND_DIR))
load_dotenv(BACKEND_DIR / ".env")
load_dotenv(ROOT / "examspark_frontend" / ".env")

SUPABASE_URL = (os.getenv("SUPABASE_URL") or "").rstrip("/")
SUPABASE_ANON = os.getenv("SUPABASE_ANON_KEY") or ""
SUPABASE_SERVICE = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_KEY") or ""
JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET") or os.getenv("JWT_SECRET") or ""


def _fail(msg: str) -> None:
    print(f"FAIL: {msg}")
    sys.exit(1)


def _ok(msg: str) -> None:
    print(f"OK: {msg}")


def check_backend_health() -> None:
    try:
        r = httpx.get("http://127.0.0.1:8000/", timeout=10)
        r.raise_for_status()
        data = r.json()
        if data.get("status") != "ExamSpark Backend Active":
            _fail(f"Unexpected health payload: {data}")
        _ok("Backend health — ExamSpark Backend Active")
    except Exception as e:  # noqa: BLE001
        _fail(f"Backend not reachable on :8000 — start uvicorn first. ({e})")


def _service_headers() -> dict[str, str]:
    return {
        "apikey": SUPABASE_SERVICE,
        "Authorization": f"Bearer {SUPABASE_SERVICE}",
        "Content-Type": "application/json",
    }


def _auth_headers(token: str) -> dict[str, str]:
    return {
        "apikey": SUPABASE_ANON,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }


def _mint_user_jwt(user_id: str, email: str | None) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": user_id,
        "aud": "authenticated",
        "role": "authenticated",
        "email": email,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(hours=1)).timestamp()),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


from app.services.supabase_admin import get_supabase_admin


def _pick_test_user() -> tuple[str, str | None]:
    admin = get_supabase_admin()
    try:
        auth_users = admin.auth.admin.list_users(page=1, per_page=1)
    except Exception as e:  # noqa: BLE001
        _fail(f"Cannot list auth users — log in via Flutter once. ({e})")
    users = getattr(auth_users, "users", None) or auth_users
    if not users:
        _fail("No auth users — log in via Flutter once.")
    user = users[0] if isinstance(users, list) else users
    user_id = user.id if hasattr(user, "id") else user.get("id")
    email = user.email if hasattr(user, "email") else user.get("email")
    if not user_id:
        _fail("Auth user missing id.")
    return user_id, email


def _ensure_plan_499(user_id: str) -> None:
    admin = get_supabase_admin()
    now = datetime.now(timezone.utc)
    end = now + timedelta(days=30)
    row = {
        "plan_id": "plan_499",
        "status": "active",
        "platform": "web",
        "gateway": "razorpay",
        "current_period_start": now.isoformat(),
        "current_period_end": end.isoformat(),
    }
    existing = (
        admin.table("user_subscriptions")
        .select("id")
        .eq("user_id", user_id)
        .order("current_period_end", desc=True)
        .limit(1)
        .execute()
    )
    if existing.data:
        admin.table("user_subscriptions").update(row).eq("id", existing.data[0]["id"]).execute()
    else:
        admin.table("user_subscriptions").insert({"user_id": user_id, **row}).execute()


def check_lecture_insert_grant(user_id: str, email: str | None) -> str:
    token = _mint_user_jwt(user_id, email)
    payload = {
        "user_id": user_id,
        "title": "Smoke Test Lecture",
        "status": "splitting",
        "source_type": "uploaded_document",
    }
    r = httpx.post(
        f"{SUPABASE_URL}/rest/v1/lectures",
        headers=_auth_headers(token),
        params={"select": "id"},
        json=payload,
        timeout=30,
    )
    if r.status_code == 403 and "group_shared_items" in r.text:
        _fail(
            "group_shared_items GRANT missing — run group_shared_items_grants_migration.sql "
            "in Supabase SQL Editor, then re-run this script."
        )
    if r.status_code not in (200, 201):
        _fail(f"Lecture insert failed ({r.status_code}): {r.text[:300]}")
    lecture_id = r.json()[0]["id"]
    _ok("Authenticated lecture insert succeeded (group_shared_items GRANT OK)")
    return lecture_id


def _minimal_jpeg_bytes() -> bytes:
    # 1x1 red JPEG — enough for vision pipeline smoke (not content quality).
    return bytes.fromhex(
        "ffd8ffe000104a46494600010100000100010000ffdb004300080606070605080707"
        "070909080a0c140d0c0b0b0c1912130f141d1a1f1e1d1a1c1c20242e2720222c"
        "231c1c2837292c30313434341f27393d38323c2e333432ffdb0043010909090c0b"
        "0c180d0d1832211c1c213232323232323232323232323232323232323232323232"
        "323232323232323232323232323232323232323232323232ffc000110800010001"
        "03011100021101031101ffc4001500010100000000000000000000000000000008"
        "ffc40014100100000000000000000000000000000000ffda000c0301000210031000"
        "3f00aaFFD9"
    )


def check_e2e_image(user_id: str, email: str | None, lecture_id: str) -> None:
    token = _mint_user_jwt(user_id, email)
    files = {"file": ("smoke.jpg", _minimal_jpeg_bytes(), "image/jpeg")}
    data = {
        "source_type": "image_upload",
        "lecture_id": lecture_id,
        "duration_minutes": "1",
    }
    r = httpx.post(
        "http://127.0.0.1:8000/api/v1/lectures/process",
        headers={"Authorization": f"Bearer {token}"},
        data=data,
        files=files,
        timeout=180,
    )
    if r.status_code != 200:
        _fail(f"FastAPI image process failed ({r.status_code}): {r.text[:400]}")
    body = r.json()
    _ok("FastAPI image process completed")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--e2e-image", action="store_true", help="Also run JPG through FastAPI (uses OpenRouter credits)")
    args = parser.parse_args()

    missing = [k for k, v in {
        "SUPABASE_URL": SUPABASE_URL,
        "SUPABASE_ANON_KEY": SUPABASE_ANON,
        "SUPABASE_SERVICE_ROLE_KEY": SUPABASE_SERVICE,
        "SUPABASE_JWT_SECRET": JWT_SECRET,
    }.items() if not v]
    if missing:
        _fail(f"Missing env keys: {', '.join(missing)}")

    print("=== Phase 5 smoke prerequisites ===")
    check_backend_health()
    user_id, email = _pick_test_user()
    _ensure_plan_499(user_id)
    _ok("Test user plan_499 ensured (service role)")
    lecture_id = check_lecture_insert_grant(user_id, email)

    if args.e2e_image:
        print("--- E2E image (OpenRouter credits) ---")
        check_e2e_image(user_id, email, lecture_id)

    print("=== ALL CHECKS PASSED ===")


if __name__ == "__main__":
    main()
