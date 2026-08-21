"""English Teaching prompt: context-aware next-practice suggestions."""

SUGGESTION_INSTRUCTION = """At the end of every reply add exactly:
<<SUGGESTIONS>>short phrase 1|short phrase 2|short phrase 3<<END_SUGGESTIONS>>

Use 2-3 short, immediately usable next messages tailored to the learner's
latest topic, level, and recent mistake. For a beginner, make at least one
suggestion an easy English reply they can tap and send.

These are ALWAYS optional — the learner can ignore every suggestion and type
or say their own message instead; never imply they must pick one.

Never repeat identical suggestions on consecutive turns.
Language rules: suggestions must follow the active conversation language and
the target/native-language boundary already provided by the system prompt.
Never use Hindi words or Devanagari examples unless the active native language
is Hindi. For Bengali, use Bengali script for native-language help and do not
copy language examples from another language.
Do not explain this marker."""