"""One-off: reset a Supabase Auth user's password via Admin API (service role).

Why this exists: founder rule says "never tell user to reset password in
Supabase dashboard" — this does it programmatically instead, using the
service-role key already in examspark_backend/.env. Safe to delete after use.

Usage (from examspark_backend/):
  python scripts/reset_founder_password.py --email busbuddy25@gmail.com --new-password "TempPass2026!"
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from app.services.supabase_admin import get_supabase_admin  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--email", required=True)
    parser.add_argument("--new-password", required=True)
    args = parser.parse_args()

    admin = get_supabase_admin()
    result = admin.auth.admin.list_users()
    users = getattr(result, "users", None) or result
    match = None
    for u in users:
        email = u.email if hasattr(u, "email") else u.get("email")
        if email and email.lower() == args.email.lower():
            match = u
            break

    if not match:
        print(f"FAIL: no auth user found with email {args.email}")
        sys.exit(1)

    user_id = match.id if hasattr(match, "id") else match.get("id")
    admin.auth.admin.update_user_by_id(user_id, {"password": args.new_password})
    print(f"OK: password updated for {args.email} (user_id={user_id})")


if __name__ == "__main__":
    main()
