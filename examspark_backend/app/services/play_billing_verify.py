"""Google Play Developer API purchase verification.

Service-account JSON path or inline JSON via GOOGLE_PLAY_SERVICE_ACCOUNT_JSON.
Live network call is skipped in unit tests (patch verify_play_purchase).
"""
from __future__ import annotations

import json
import logging
import os
from typing import Any

from app.config import PaymentConfig
from app.constants.payment_catalog import is_play_subscription_product

logger = logging.getLogger(__name__)

_ANDROIDPUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"


def _load_service_account_info() -> dict[str, Any]:
    raw = PaymentConfig.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON.strip()
    if not raw:
        raise RuntimeError("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON not set")
    if os.path.isfile(raw):
        with open(raw, encoding="utf-8") as f:
            return json.load(f)
    return json.loads(raw)


def verify_play_purchase(
    *,
    product_id: str,
    purchase_token: str,
    package_name: str | None = None,
) -> bool:
    """Return True if Play Developer API confirms a valid purchase.

    Subscriptions use purchases.subscriptions.get;
    credit packs use purchases.products.get.
    """
    if not product_id or not purchase_token:
        return False
    if not PaymentConfig.google_play_configured():
        return False

    package = package_name or PaymentConfig.GOOGLE_PLAY_PACKAGE_NAME
    if not package:
        return False

    try:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build
    except ImportError:
        logger.error(
            "google-api-python-client / google-auth not installed — "
            "pip install google-api-python-client google-auth"
        )
        return False

    try:
        info = _load_service_account_info()
        credentials = service_account.Credentials.from_service_account_info(
            info,
            scopes=[_ANDROIDPUBLISHER_SCOPE],
        )
        service = build(
            "androidpublisher", "v3", credentials=credentials, cache_discovery=False
        )

        if is_play_subscription_product(product_id):
            result = (
                service.purchases()
                .subscriptions()
                .get(
                    packageName=package,
                    subscriptionId=product_id,
                    token=purchase_token,
                )
                .execute()
            )
            # paymentState: 1 = received, 2 = free trial, 3 = pending deferred
            payment_state = result.get("paymentState")
            if payment_state is not None and payment_state not in (1, 2):
                logger.warning(
                    "Play subscription paymentState=%s product=%s",
                    payment_state,
                    product_id,
                )
                return False
            # expiryTimeMillis in past → expired
            expiry = result.get("expiryTimeMillis")
            if expiry is not None and int(expiry) < _now_ms():
                logger.warning("Play subscription expired product=%s", product_id)
                return False
            return True

        result = (
            service.purchases()
            .products()
            .get(
                packageName=package,
                productId=product_id,
                token=purchase_token,
            )
            .execute()
        )
        # purchaseState: 0 = purchased
        if result.get("purchaseState", 0) != 0:
            return False
        return True
    except Exception as e:  # noqa: BLE001
        logger.exception("Play purchase verify failed: %s", e)
        return False


def _now_ms() -> int:
    import time

    return int(time.time() * 1000)
