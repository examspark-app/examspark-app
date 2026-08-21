import re

from app.constants.english_roleplay_prompt import build_roleplay_prompt


def test_roleplay_prompt_has_short_to_long_pacing_contract():
    prompt = build_roleplay_prompt(
        scenario='Party',
        native_language='Hindi',
        target_language='English',
        turn_number=0,
    )

    assert 'Turn 0 (the opening) and turns 1-2' in prompt
    assert 'one very short, simple beat' in prompt
    assert 'Turns 3-5' in prompt
    assert 'Turn 6 onward' in prompt


def test_roleplay_prompt_preserves_distinct_scenario_context():
    party = build_roleplay_prompt(
        scenario='Party', native_language='Hindi', target_language='English'
    )
    restaurant = build_roleplay_prompt(
        scenario='Restaurant', native_language='Hindi', target_language='English'
    )

    assert 'Scenario: Party' in party
    assert 'music-drinks-food' in party
    assert 'Scenario: Restaurant' in restaurant
    assert 'menus-table-names-food-drink-cuisine' in restaurant
    assert party != restaurant


def test_roleplay_prompt_requires_learning_continuity_without_forcing_it():
    prompt = build_roleplay_prompt(
        scenario='Friends',
        native_language='Hindi',
        target_language='English',
        learning_memory=(
            'Learner memory:\n- Practised topics: introductions\n'
            '- Recurring mistakes: past tense'
        ),
    )

    assert 'LEARNING CONTINUITY' in prompt
    normalized = re.sub(r'\s+', ' ', prompt)
    assert 'reinforce or extend exactly ONE relevant item' in normalized
    assert 'Do not force an unrelated memory item' in prompt
