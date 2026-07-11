"""Payment security primitives — verification stubs until live keys."""
import hashlib
import time
from typing import Optional

from app.config import PaymentConfig


class PaymentSecurity:
    """Webhook verification, replay protection, idempotency."""

    # In-memory idempotency store — replace with Redis in production
    _idempotency_cache: dict[str, tuple[float, dict]] = {}

    @staticmethod
    def verify_razorpay_signature(
        payload: bytes,
        signature: str,
        webhook_secret: Optional[str] = None,
    ) -> bool:
        # TODO: Razorpay Integration
        # Use hmac.compare_digest with RAZORPAY_WEBHOOK_SECRET
        secret = webhook_secret or PaymentConfig.RAZORPAY_WEBHOOK_SECRET
        if not secret:
            return False
        return False  # Not implemented

    @staticmethod
    def verify_phonepe_signature(payload: bytes, signature: str) -> bool:
        # TODO: PhonePe Integration
        if not PaymentConfig.PHONEPE_SALT_KEY:
            return False
        return False

    @staticmethod
    def verify_google_play_purchase(
        package_name: str,
        product_id: str,
        purchase_token: str,
    ) -> bool:
        # TODO: Google Play Billing — server-side verification via Play Developer API
        if not PaymentConfig.google_play_configured():
            return False
        return False

    @staticmethod
    def is_replay(event_id: str, seen_events: set[str]) -> bool:
        """Replay protection — event_id must be unique per gateway."""
        if event_id in seen_events:
            return True
        seen_events.add(event_id)
        return False

    @classmethod
    def check_idempotency(cls, key: str) -> Optional[dict]:
        """Return cached response if key already processed."""
        entry = cls._idempotency_cache.get(key)
        if not entry:
            return None
        expires_at, response = entry
        if time.time() > expires_at:
            del cls._idempotency_cache[key]
            return None
        return response

    @classmethod
    def store_idempotency(cls, key: str, response: dict) -> None:
        ttl = PaymentConfig.IDEMPOTENCY_TTL_SECONDS
        cls._idempotency_cache[key] = (time.time() + ttl, response)

    @staticmethod
    def hash_payload(payload: bytes) -> str:
        return hashlib.sha256(payload).hexdigest()

    @staticmethod
    def prevent_duplicate_payment(
        order_id: str,
        existing_status: Optional[str],
    ) -> bool:
        """True if payment already verified — block duplicate activation."""
        return existing_status == "verified"
