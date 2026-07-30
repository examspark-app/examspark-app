"""Supabase auth verification — every non-public FastAPI route depends on this.

Prefer local JWT verification when the legacy shared `SUPABASE_JWT_SECRET` is
configured. That avoids a network call to Supabase Auth on every notes/extras
request, which can otherwise make Flutter Web show a generic "Failed to fetch"
when Auth is slow. If the project uses newer asymmetric keys or the local secret
doesn't match, fall back to Supabase's `/auth/v1/user` with a short timeout.
"""
import os

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import httpx
import jwt
from jwt import ExpiredSignatureError, InvalidTokenError

from app.services.supabase_admin import _supabase_key, _supabase_url

_bearer_scheme = HTTPBearer(auto_error=False)
_jwt_secret = os.getenv("SUPABASE_JWT_SECRET", "").strip()
_auth_timeout_seconds = float(os.getenv("SUPABASE_AUTH_TIMEOUT_SECONDS", "8"))


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

    token = credentials.credentials

    if _jwt_secret:
        try:
            claims = jwt.decode(
                token,
                _jwt_secret,
                algorithms=["HS256"],
                audience="authenticated",
            )
            user_id = claims.get("sub")
            if user_id:
                return AuthenticatedUser(
                    user_id=user_id,
                    email=claims.get("email"),
                    raw_claims=claims,
                )
        except ExpiredSignatureError as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired token.",
            ) from e
        except InvalidTokenError:
            # Secret may be stale, or the Supabase project may use asymmetric
            # signing keys. Ask Supabase directly before rejecting the request.
            pass

    if not _supabase_url or not _supabase_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not configured on the server.",
        )

    try:
        async with httpx.AsyncClient(timeout=_auth_timeout_seconds) as client:
            response = await client.get(
                f"{_supabase_url.rstrip('/')}/auth/v1/user",
                headers={
                    "apikey": _supabase_key,
                    "Authorization": f"Bearer {token}",
                },
            )
    except httpx.TimeoutException as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Supabase Auth timeout. Retry in a few seconds.",
        ) from e
    except httpx.HTTPError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Supabase Auth unavailable: {e}",
        ) from e

    if response.status_code == 401:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token.",
        )
    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Supabase Auth failed: {response.status_code}",
        )

    user = response.json()
    user_id = user.get("id")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token.",
        )

    return AuthenticatedUser(
        user_id=user_id,
        email=user.get("email"),
        raw_claims=user,
    )
