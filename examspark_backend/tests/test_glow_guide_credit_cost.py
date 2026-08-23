from app.services.glow_guide_service import glow_guide_credit_cost


def test_glow_guide_text_is_2_credits():
    assert glow_guide_credit_cost(False) == 2


def test_glow_guide_photo_is_5_credits():
    assert glow_guide_credit_cost(True) == 5
