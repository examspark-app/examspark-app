"""Payment security — Razorpay HMAC, idempotency, replay protection."""
import hashlib
import hmac
import time
from typing import Optional

from app.config import PaymentConfig


class PaymentSecurity:
    """Webhook verification, payment signature, replay protection, idempotency."""

    # In-memory idempotency store — Redis preferred at scale
    _idempotency_cache: dict[str, tuple[float, dict]] = {}

    @staticmethod
    def verify_razorpay_webhook_signature(
        payload: bytes,
        signature: str,
        webhook_secret: Optional[str] = None,
    ) -> bool:
        """HMAC-SHA256 of raw body with RAZORPAY_WEBHOOK_SECRET."""
        secret = webhook_secret or PaymentConfig.RAZORPAY_WEBHOOK_SECRET
        if not secret or not signature:
            return False
        expected = hmac.new(
            secret.encode("utf-8"),
            payload,
            hashlib.sha256,
        ).hexdigest()
        return hmac.compare_digest(expected, signature)

    @staticmethod
    def verify_razorpay_signature(
        payload: bytes,
        signature: str,
        webhook_secret: Optional[str] = None,
    ) -> bool:
        """Alias used by webhook_service — webhook body HMAC."""
        return PaymentSecurity.verify_razorpay_webhook_signature(
            payload, signature, webhook_secret
        )

    @staticmethod
    def verify_razorpay_payment_signature(
        gateway_order_id: str,
        gateway_payment_id: str,
        signature: str,
        key_secret: Optional[str] = None,
    ) -> bool:
        """Checkout signature: HMAC-SHA256(order_id|payment_id, KEY_SECRET)."""
        secret = key_secret or PaymentConfig.RAZORPAY_KEY_SECRET
        if not secret or not gateway_order_id or not gateway_payment_id or not signature:
            return False
        message = f"{gateway_order_id}|{gateway_payment_id}".encode("utf-8")
        expected = hmac.new(
            secret.encode("utf-8"),
            message,
            hashlib.sha256,
        ).hexdigest()
        return hmac.compare_digest(expected, signature)

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
        from app.services.play_billing_verify import verify_play_purchase

        if not PaymentConfig.google_play_configured():
            return False
        return verify_play_purchase(
            product_id=product_id,
            purchase_token=purchase_token,
            package_name=package_name,
        )

    @staticmethod
    def is_replay(event_id: str, seen_events: set[str]) -> bool:
        """Replay protection — event_id must be unique per gateway."""
        if not event_id:
            return False
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

    @classmethod
    def clear_idempotency_for_tests(cls) -> None:
        cls._idempotency_cache.clear()

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
