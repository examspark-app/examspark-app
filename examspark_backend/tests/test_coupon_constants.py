"""Coupon constants + code shape tests (no live Supabase)."""
from app.services.coupon_service import (
    COUPON_ACCESS_DAYS,
    COUPON_CREDITS,
    COUPON_MAX_REDEMPTIONS,
    COUPON_URGENCY_DAYS,
    _generate_code,
)


def test_coupon_business_constants():
    assert COUPON_CREDITS == 0  # Free 50/mo already; no extra on coupon
    assert COUPON_MAX_REDEMPTIONS == 100
    assert COUPON_ACCESS_DAYS == 30
    assert COUPON_URGENCY_DAYS == 7


def test_generate_code_length_and_charset():
    code = _generate_code(8)
    assert len(code) == 8
    assert code.isalnum()
    assert code == code.upper()
