"""Google Play Billing — Android subscriptions + one-time packs."""
import asyncio
import json
import logging
from typing import Any
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

from app.config import PaymentConfig
from app.constants.payment_catalog import play_product_id_for
from app.models.payment import (
    CreateOrderResponse,
    PaymentGateway,
    PaymentPlatform,
    PaymentStatus,
)
from app.services.gateways.base import PaymentGatewayBase

logger = logging.getLogger(__name__)


def _verify_and_acknowledge_sync(
    product_id: str,
    purchase_token: str,
    is_subscription: bool = False,
) -> bool:
    """Synchronous internal helper that calls Google Play Publisher API."""
    if not PaymentConfig.google_play_configured():
        logger.warning("Google Play not configured (google_play_configured() = False)")
        return False

    package_name = getattr(PaymentConfig, "GOOGLE_PLAY_PACKAGE_NAME", "")
    service_account_json = getattr(
        PaymentConfig, "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", ""
    )

    if not package_name or not service_account_json:
        logger.warning(
            "Missing package_name=%r or service_account_json is empty",
            package_name,
        )
        return False

    logger.info(
        "Verifying Play purchase: package=%s product_id=%s is_subscription=%s token=%s...",
        package_name, product_id, is_subscription, purchase_token[:15],
    )

    try:
        service_account_info = json.loads(service_account_json)
        credentials = service_account.Credentials.from_service_account_info(
            service_account_info,
            scopes=["https://www.googleapis.com/auth/androidpublisher"],
        )
        service = build("androidpublisher", "v3", credentials=credentials)

        if is_subscription:
            sub = (
                service.purchases()
                .subscriptions()
                .get(
                    packageName=package_name,
                    subscriptionId=product_id,
                    token=purchase_token,
                )
                .execute()
            )
            logger.info("Subscription verify response: %s", sub)

            if sub.get("paymentState") == 1:
                if sub.get("acknowledgementState") == 0:
                    service.purchases().subscriptions().acknowledge(
                        packageName=package_name,
                        subscriptionId=product_id,
                        token=purchase_token,
                    ).execute()
                return True
            return False

        else:
            prod = (
                service.purchases()
                .products()
                .get(
                    packageName=package_name,
                    productId=product_id,
                    token=purchase_token,
                )
                .execute()
            )
            logger.info("Product verify response: %s", prod)

            if prod.get("purchaseState") == 0:
                if prod.get("acknowledgementState") == 0:
                    service.purchases().products().acknowledge(
                        packageName=package_name,
                        productId=product_id,
                        token=purchase_token,
                        body={},
                    ).execute()
                return True
            return False

    except HttpError as e:
        logger.error(
            "Google Play API HttpError: status=%s content=%s",
            e.resp.status, e.content,
        )
        return False
    except Exception:
        logger.exception("Google Play verification failed with unexpected error")
        return False


async def verify_play_purchase(
    product_id: str,
    purchase_token: str,
    is_subscription: bool = False,
) -> bool:
    """Non-blocking async wrapper to prevent blocking the FastAPI event loop."""
    return await asyncio.to_thread(
        _verify_and_acknowledge_sync,
        product_id=product_id,
        purchase_token=purchase_token,
        is_subscription=is_subscription,
    )


class GooglePlayGateway(PaymentGatewayBase):
    gateway = PaymentGateway.GOOGLE_PLAY

    async def create_order(
        self,
        order_id: str,
        amount_paise: int,
        currency: str,
        user_id: str,
        plan_id: str,
        platform: PaymentPlatform,
        metadata: dict[str, Any],
    ) -> CreateOrderResponse:
        credit_pack_id = metadata.get("credit_pack_id")
        try:
            product_id = play_product_id_for(
                plan_id=plan_id or None,
                credit_pack_id=credit_pack_id,
            )
        except ValueError as e:
            return CreateOrderResponse(
                order_id=order_id,
                status=PaymentStatus.FAILED,
                amount_paise=amount_paise,
                currency=currency,
                gateway=self.gateway,
                message=str(e),
            )

        package = PaymentConfig.GOOGLE_PLAY_PACKAGE_NAME or ""
        msg = (
            "Play purchase intent recorded — complete Billing on Android"
            if package
            else (
                "Play purchase intent recorded — set GOOGLE_PLAY_PACKAGE_NAME "
                "and service account before verify will succeed"
            )
        )
        return CreateOrderResponse(
            order_id=order_id,
            status=PaymentStatus.PENDING,
            amount_paise=amount_paise,
            currency=currency,
            gateway=self.gateway,
            gateway_order_id=product_id,
            google_play_product_id=product_id,
            message=msg,
        )

    async def verify_payment(
        self,
        order_id: str,
        gateway_payment_id: str | None,
        signature: str | None,
        payload: dict[str, Any],
    ) -> bool:
        purchase_token = (
            payload.get("purchase_token")
            or gateway_payment_id
            or payload.get("purchaseToken")
        )
        product_id = (
            payload.get("product_id")
            or payload.get("productId")
            or payload.get("gateway_order_id")
        )
        is_subscription = bool(
            payload.get("is_subscription")
            or payload.get("isSubscription")
            or False
        )

        if not purchase_token or not product_id:
            logger.warning(
                "Missing purchase_token=%r or product_id=%r in payload=%s",
                purchase_token, product_id, payload,
            )
            return False

        if not PaymentConfig.google_play_configured():
            return False

        return await verify_play_purchase(
            product_id=str(product_id),
            purchase_token=str(purchase_token),
            is_subscription=is_subscription,
        )