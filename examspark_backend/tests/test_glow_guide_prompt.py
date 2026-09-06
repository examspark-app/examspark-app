from app.constants.glow_guide_prompt import system_prompt


def test_glow_guide_uses_consistent_consultant_identity():
    prompt = system_prompt("skin", "My skin feels oily")

    assert "board-certified dermatologist" not in prompt
    assert "science-based skin and product-fit consultant" in prompt


def test_glow_guide_does_not_request_a_duplicate_verdict_card():
    prompt = system_prompt("skin", "Is this suitable for oily skin?")

    assert "do NOT repeat a rating card" in prompt
