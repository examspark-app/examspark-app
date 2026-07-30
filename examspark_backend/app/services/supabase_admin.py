"""Shared service-role Supabase client for backend-internal DB writes.

Service-role key bypasses RLS — only use from trusted server code (never
exposed to Flutter). This is the same client `main.py`'s health check uses;
importing it here avoids every service creating its own connection.
"""
import os

from dotenv import load_dotenv
from supabase import Client, create_client

load_dotenv()

_supabase_url = os.getenv("SUPABASE_URL", "")
_supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_KEY", "")

_client: Client | None = None


def get_supabase_admin() -> Client:
    global _client
    if _client is None:
        if not _supabase_url or not _supabase_key:
            raise RuntimeError("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not configured on the server.")
        _client = create_client(_supabase_url, _supabase_key)
    return _client
