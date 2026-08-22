from app.constants.english_roleplay_prompt import build_roleplay_prompt


PROFESSIONAL_MODES = (
    "Office / Citizen",
    "Online Client Meeting",
    "Job Interview",
    "Job Test / Screening Chat",
    "Citizenship Test",
    "Visa Interview",
)


def test_professional_modes_have_distinct_prompt_guidance():
    prompts = {
        mode: build_roleplay_prompt(
            scenario=mode,
            native_language="Hindi",
            target_language="English",
        )
        for mode in PROFESSIONAL_MODES
    }

    assert all(f"Scenario: {mode}" in prompt for mode, prompt in prompts.items())
    assert "relaxed desk greetings" in prompts["Office / Citizen"]
    assert "video-call introductions" in prompts["Online Client Meeting"]
    assert "one common question at a" in prompts["Job Interview"]
    assert "structured but low-pressure HR screening" in prompts[
        "Job Test / Screening Chat"
    ]
    assert "which country" in prompts["Citizenship Test"]
    assert "history/government questions" in prompts["Citizenship Test"]
    assert "what visa" in prompts["Visa Interview"]
    assert "funding" in prompts["Visa Interview"]


def test_new_modes_keep_short_to_long_and_varied_opening_contracts():
    prompt = build_roleplay_prompt(
        scenario="Job Interview",
        native_language="Hindi",
        target_language="English",
        turn_number=0,
    )

    assert "Turn 0 (the opening) and turns 1-2" in prompt
    assert "Turns 3-5" in prompt
    assert "Turn 6 onward" in prompt
    assert "invented-for-this-scenario" in prompt
    assert "vary it" in prompt
