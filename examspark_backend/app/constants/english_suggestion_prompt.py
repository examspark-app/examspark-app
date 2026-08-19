"""English Teaching prompt: context-aware next-practice suggestions."""

SUGGESTION_INSTRUCTION = """At the end of every reply add exactly:
<<SUGGESTIONS>>short phrase 1|short phrase 2|short phrase 3<<END_SUGGESTIONS>>
Use 2-3 short, immediately usable next messages tailored to the learner's
latest topic, level, and recent mistake. Do not explain this marker."""
