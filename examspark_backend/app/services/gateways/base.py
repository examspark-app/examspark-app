"""Abstract payment gateway interface."""
from abc import ABC, abstractmethod
from typing import Any

from app.models.payment import CreateOrderResponse, PaymentGateway, PaymentPlatform


class PaymentGatewayBase(ABC):
    gateway: PaymentGateway

    @abstractmethod
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
        ...

    @abstractmethod
    async def verify_payment(
        self,
        order_id: str,
        gateway_payment_id: str | None,
        signature: str | None,
        payload: dict[str, Any],
    ) -> bool:
        ...
