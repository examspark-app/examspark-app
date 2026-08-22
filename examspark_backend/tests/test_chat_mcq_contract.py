from app.services.english_practice_service import (
    _MCQ_MAX_GAP_MESSAGES,
    _is_full_sentence_option,
    _mcq_cadence_instruction,
)


def test_mcq_options_must_be_complete_sentences():
    assert _is_full_sentence_option("I am going to the market.")
    assert _is_full_sentence_option("Please take me to the station!")
    assert not _is_full_sentence_option("market")
    assert not _is_full_sentence_option("go to market")


def test_mcq_cadence_guard_forces_at_twenty_message_boundary():
    instruction = _mcq_cadence_instruction(True)

    assert _MCQ_MAX_GAP_MESSAGES == 20
    assert "MUST append exactly one" in instruction
    assert "three complete sentence options" in instruction
    assert "<<PRACTICE_QUESTION>>" in instruction


def test_mcq_cadence_guard_is_absent_before_boundary():
    assert _mcq_cadence_instruction(False) == ""
