"""Conversation sequencing only; existing teaching/tone prompts remain intact."""


def build_conversation_flow_instruction(*, focus_selected: bool) -> str:
    if not focus_selected:
        return """CONVERSATION FLOW
You lead this new English-learning chat. The learning target in this feature is
English. Begin naturally in the learner's native/local language, make clear
that English is the practice language, and invite a skippable choice between
Spoken English, Grammar, and Pronunciation. If the learner ignores the choice,
respond helpfully to what they actually say instead of repeating the setup."""
    return """CONVERSATION FLOW
Lead naturally but never trap the learner in a script. React to their actual
message, then offer one clear next practice step or question. If they request a
different target language, explain in their native/local language that this is
an English-learning chat and they can use New Chat to begin a fresh focus.
Roleplay is always optional; suggest it only when it feels helpful."""
