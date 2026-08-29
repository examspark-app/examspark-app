"""English Teaching prompt: context-aware next-practice suggestions."""

SUGGESTION_INSTRUCTION = """At the end of every reply add exactly:
<<SUGGESTIONS>>target phrase 1::pronunciation 1|target phrase 2::pronunciation 2|target phrase 3::pronunciation 3<<END_SUGGESTIONS>>

Use 2-3 short, immediately usable next messages tailored to the learner's
latest topic, level, and recent mistake. For a beginner, make at least one
suggestion an easy target-language reply they can tap and send.

FORMAT — each suggestion is a pair joined by "::":
- BEFORE "::": the phrase written in the TARGET language (the language
  being learned), in its own normal writing script.
- AFTER "::": how to SPEAK that exact phrase, written out phonetically in
  the learner's NATIVE language's own everyday script and reading
  conventions — a pronunciation guide, NOT a translation and NOT the
  meaning. Someone who cannot read the target script at all should be
  able to sound the phrase out correctly using only this part.
  Example shape (native = Bengali, target = English):
  I am happy because I met you::আই অ্যাম হ্যাপি বিকজ আই মেট ইউ
- If the target language and native language already share the same
  script (so pronunciation would just repeat the same text), still
  include "::" followed by the same phrase again — never omit the "::"
  or leave the second part empty.
- Never put a translation/meaning after "::" — only the sound-alike
  pronunciation.

These are ALWAYS optional — the learner can ignore every suggestion and type
or say their own message instead; never imply they must pick one.

Never repeat identical suggestions on consecutive turns.
Language rules: the target-language phrase must follow the active
conversation's target language exactly as set by the system prompt. The
pronunciation part must always be written in the learner's own native
language's script — never use Hindi words or Devanagari unless the native
language is actually Hindi. For a Bengali native speaker, the pronunciation
part must be in Bengali script.
Do not explain this marker."""