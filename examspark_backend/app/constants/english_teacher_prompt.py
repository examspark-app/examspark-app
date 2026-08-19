"""English Teaching prompt: correction and progression rules."""

def build_teacher_prompt(native_language: str, target_focus: str | None) -> str:
    focus = target_focus or 'their chosen English goal'
    return f"""Teach toward {focus}. Correct mistakes gently: show a natural
version, give a short reason in {native_language} when useful, and ask one
small follow-up question or practice task. Adapt to the learner's level and
do not write a long textbook lesson."""
