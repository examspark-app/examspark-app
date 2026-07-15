"""Supabase auth verification — every non-public FastAPI route depends on this.

Previously verified the Supabase access token's signature locally with a
shared `SUPABASE_JWT_SECRET` copied from the dashboard. That breaks the
instant the `.env` value drifts from the dashboard's current secret, and
can never work at all on projects using Supabase's newer asymmetric "JWT
Signing Keys" instead of a legacy shared secret — both looked identical to
callers ("Invalid token." on every request). Now we ask Supabase itself to
verify the token (`GET /auth/v1/user` via `get_user()`), which is
authoritative regardless of which signing method the project uses, and
needs no local secret to stay in sync.
"""
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from supabase_auth.errors import AuthApiError

from app.services.supabase_admin import get_supabase_admin

_bearer_scheme = HTTPBearer(auto_error=False)


class AuthenticatedUser:
    """Minimal identity extracted from a Supabase-verified access token."""

    def __init__(self, user_id: str, email: str | None, raw_claims: dict):
        self.user_id = user_id
        self.email = email
        self.raw_claims = raw_claims


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
) -> AuthenticatedUser:
    """FastAPI dependency — use as `user: AuthenticatedUser = Depends(get_current_user)`."""
    if credentials is None or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization: Bearer <supabase_access_token> header.",
        )

    try:
        response = get_supabase_admin().auth.get_user(credentials.credentials)
    except AuthApiError as e:
        # Covers expired, malformed, and signature-invalid tokens alike —
        # Supabase's own error message (e.g. "invalid JWT: ... expired")
        # is more specific than we could produce locally.
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)) from e

    user = response.user if response else None
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token.")

    return AuthenticatedUser(
        user_id=user.id,
        email=user.email,
        raw_claims=user.model_dump() if hasattr(user, "model_dump") else {},
    )
