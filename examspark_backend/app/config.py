"""Payment configuration — keys empty until production."""
import os
from dotenv import load_dotenv

load_dotenv()


class PaymentConfig:
    # TODO: Razorpay Integration
    RAZORPAY_KEY_ID: str = os.getenv("RAZORPAY_KEY_ID", "")
    RAZORPAY_KEY_SECRET: str = os.getenv("RAZORPAY_KEY_SECRET", "")
    RAZORPAY_WEBHOOK_SECRET: str = os.getenv("RAZORPAY_WEBHOOK_SECRET", "")

    # TODO: PhonePe Integration
    PHONEPE_MERCHANT_ID: str = os.getenv("PHONEPE_MERCHANT_ID", "")
    PHONEPE_SALT_KEY: str = os.getenv("PHONEPE_SALT_KEY", "")
    PHONEPE_WEBHOOK_SECRET: str = os.getenv("PHONEPE_WEBHOOK_SECRET", "")

    # TODO: Google Play Billing — server-side verification
    GOOGLE_PLAY_PACKAGE_NAME: str = os.getenv("GOOGLE_PLAY_PACKAGE_NAME", "")
    GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: str = os.getenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "")

    IDEMPOTENCY_TTL_SECONDS: int = int(os.getenv("PAYMENT_IDEMPOTENCY_TTL", "86400"))

    @classmethod
    def razorpay_configured(cls) -> bool:
        return bool(cls.RAZORPAY_KEY_ID and cls.RAZORPAY_KEY_SECRET)

    @classmethod
    def phonepe_configured(cls) -> bool:
        return bool(cls.PHONEPE_MERCHANT_ID and cls.PHONEPE_SALT_KEY)

    @classmethod
    def google_play_configured(cls) -> bool:
        return bool(cls.GOOGLE_PLAY_PACKAGE_NAME and cls.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON)
