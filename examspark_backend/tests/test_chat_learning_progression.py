from app.services.english_practice_service import _system_prompt


def test_chat_prompt_contains_situational_progression_and_flexible_handoff():
    prompt = _system_prompt("Hindi", target_focus="speaking", target_language="English")

    assert "Stage 2 practical situational learning" in prompt
    assert "taxi driver" in prompt
    assert "asking a shop price" in prompt
    assert "never require a New Chat" in prompt
    assert "move into Roleplay Mode" in prompt
    assert "never switch silently or force the handoff" in prompt


def test_chat_prompt_requires_correction_retry_and_speaking_tip():
    prompt = _system_prompt("Hindi", target_focus="speaking", target_language="English")

    assert "CORRECTION AND RETRY" in prompt
    assert "Invite an actual retry" in prompt
    assert "speaking slowly" in prompt
    assert "phrase into two parts" in prompt
    assert "natural Hindi" in prompt


def test_native_language_rules_reach_final_chat_prompt_for_multiple_scripts():
    hindi_prompt = _system_prompt("Hindi", target_focus="grammar", target_language="Tamil")
    bengali_prompt = _system_prompt("Bengali", target_focus="speaking", target_language="Sanskrit")

    for prompt, native, target in (
        (hindi_prompt, "Hindi", "Tamil"),
        (bengali_prompt, "Bengali", "Sanskrit"),
    ):
        assert f"The student's native/local language is: {native}." in prompt
        assert f"The language the student is learning (target language) is: {target}." in prompt
        assert f"Write {native} the way an actual native speaker casually talks" in prompt
        assert "ABSOLUTELY NEVER produce" in prompt
        assert "SCRIPT DIFFERENT" in prompt
        assert "pronunciation guide" in prompt
