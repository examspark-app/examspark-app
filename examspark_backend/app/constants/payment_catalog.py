"""Server-side payment catalog — never trust client amounts.

Mirrors subscription_plans / credit_packs in schema.sql and
examspark_frontend/lib/core/payments/subscription_plans.dart.
Paid plan credits are that plan's package only — never Free 50 stacked.
"""

PLAN_PRICES_PAISE: dict[str, int] = {
    "plan_199": 19_900,
    "plan_299": 29_900,  # optional re-entry tier
    "plan_499": 49_900,
    "plan_999": 99_900,
    "teacher": 199_900,
}

PLAN_MONTHLY_CREDITS: dict[str, int] = {
    "free": 50,
    "plan_199": 1500,
    "plan_299": 1500,
    "plan_499": 3500,
    "plan_999": 8000,
    "teacher": 16000,
}

PACK_PRICES_PAISE: dict[str, int] = {
    "pack_100": 2_500,
    "pack_500": 11_000,
    "pack_1000": 20_000,
    "pack_5000": 85_000,
    "pack_10000": 150_000,
}

PACK_CREDITS: dict[str, int] = {
    "pack_100": 100,
    "pack_500": 500,
    "pack_1000": 1000,
    "pack_5000": 5000,
    "pack_10000": 10000,
}


def resolve_amount_paise(plan_id: str | None, credit_pack_id: str | None) -> int:
    if credit_pack_id:
        amount = PACK_PRICES_PAISE.get(credit_pack_id)
        if amount is None:
            raise ValueError(f"Unknown credit pack: {credit_pack_id}")
        return amount
    if not plan_id or plan_id == "free":
        raise ValueError("Paid plan_id required (free plan cannot be purchased)")
    amount = PLAN_PRICES_PAISE.get(plan_id)
    if amount is None:
        raise ValueError(f"Unknown plan: {plan_id}")
    return amount


def credits_for_plan(plan_id: str) -> int:
    return PLAN_MONTHLY_CREDITS.get(plan_id, 0)


def credits_for_pack(pack_id: str) -> int:
    return PACK_CREDITS.get(pack_id, 0)


# Google Play product IDs — must match Play Console exactly (founder guide).
# Subscriptions for plans; one-time in-app products for credit packs.
PLAN_TO_PLAY_PRODUCT: dict[str, str] = {
    "plan_199": "examspark_plan_199",
    "plan_299": "examspark_plan_299",
    "plan_499": "examspark_plan_499",
    "plan_999": "examspark_plan_999",
    "teacher": "examspark_plan_teacher",
}

PACK_TO_PLAY_PRODUCT: dict[str, str] = {
    "pack_100": "examspark_pack_100",
    "pack_500": "examspark_pack_500",
    "pack_1000": "examspark_pack_1000",
    "pack_5000": "examspark_pack_5000",
    "pack_10000": "examspark_pack_10000",
}

PLAY_PRODUCT_TO_PLAN: dict[str, str] = {v: k for k, v in PLAN_TO_PLAY_PRODUCT.items()}
PLAY_PRODUCT_TO_PACK: dict[str, str] = {v: k for k, v in PACK_TO_PLAY_PRODUCT.items()}


def play_product_id_for(*, plan_id: str | None, credit_pack_id: str | None) -> str:
    if credit_pack_id:
        product = PACK_TO_PLAY_PRODUCT.get(credit_pack_id)
        if not product:
            raise ValueError(f"No Play product for pack: {credit_pack_id}")
        return product
    if not plan_id or plan_id == "free":
        raise ValueError("Paid plan_id required for Play product")
    product = PLAN_TO_PLAY_PRODUCT.get(plan_id)
    if not product:
        raise ValueError(f"No Play product for plan: {plan_id}")
    return product


def is_play_subscription_product(product_id: str) -> bool:
    return product_id in PLAY_PRODUCT_TO_PLAN


def resolve_catalog_from_play_product(product_id: str) -> tuple[str | None, str | None]:
    """Returns (plan_id, credit_pack_id)."""
    if product_id in PLAY_PRODUCT_TO_PLAN:
        return PLAY_PRODUCT_TO_PLAN[product_id], None
    if product_id in PLAY_PRODUCT_TO_PACK:
        return None, PLAY_PRODUCT_TO_PACK[product_id]
    raise ValueError(f"Unknown Play product_id: {product_id}")
