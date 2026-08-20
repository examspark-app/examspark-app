# Verification Checklist + Learner Name Feature — Implementation Plan

## 0. Verification Status Summary (Research Result)

| # | Section | Status | Detail |
|---|---|---|---|
| 1 | Two-language separation | **Partially** | Prompt infra uses `native_language` vs `target_language` correctly; but **Roleplay has no MCQ extraction** and the roleplay system prompt does **not** include the MCQ rules block. Also roleplay UI is voice-only and has no text/MCQ surface at all. |
| 2 | Suggestion/MCQ in Roleplay mode | **No** | Backend `english_roleplay_service.start() / send_turn() / stream_*` never run `_split_and_extract`, no `mcq` key in response payloads; roleplay system prompt has no `<<PRACTICE_MCQ>>` generation rules; Flutter `RoleplayVoiceScreen` has no MCQ/Suggestions UI widgets and is a voice-only fullscreen flow. |
| 3 | AI always goes first in Roleplay | **Yes (infra), Partial (genericness)** | Infra confirmed: backend `start()` calls `_call_model` with opening instruction, persists as `assistant` message BEFORE returning; Flutter plays TTS, then starts mic (waits for user). Single turn only — no second message. **Cannot verify non-genericness** without live LLM key (no mocked openings in tests); need prompt-level hardening + a live test to capture 2–3 real samples. |
| 4 | Learner's name (NEW) | **No** | No field anywhere for learner_name; memory service `english_learning_memory` has no `learner_name` column; neither `english_chat_prompt.py` nor `english_roleplay_prompt.py` mentions anything about asking for or using a name. |

---

## 1. Two-Language Separation — Hardening Actions

**Files:**
- [english_roleplay_prompt.py](file:///C:/Users/MIRZA%20COMPUTER/Documents/ExamSpark-Project/examspark_backend/app/constants/english_roleplay_prompt.py)
- [english_chat_prompt.py](file:///C:/Users/MIRZA%20COMPUTER/Documents/ExamSpark-Project/examspark_backend/app/constants/english_chat_prompt.py)

**Steps:**
1. **Make language-boundary rules explicit and identical** in both prompt files with a new subsection. Require:
   - Teaching explanations / hints / corrections / encouragements → always in `{native_language}` (with native script if script differs, casual register, NOT stiff/translated).
   - The spoken/drilled content of roleplay, example sentences, vocabulary items, MCQ question text, and MCQ option text → always in `{target_language}` (with `{native_language}` pronunciation guide in brackets `()` immediately after any target-language word whose script differs from `{native_language}`'s script).
   - Answer input (free-form) is ALWAYS the learner typing/speaking in their native language, EXCEPT when roleplay explicitly asks them to speak target-language.
   - AI MUST NOT swap or mix: no teaching paragraph in target language, no roleplay-dialogue line in native language.
2. **Add MCQ language rules block** (copied from user spec) into roleplay prompt — currently it only exists in chat prompt.
3. Add a **non-stiff-register rule** for native-language portions (repeat of the roleplay prompt's good rule): word choice / word order that a real native speaker would use chatting casually, never a word-for-word calque from English.
4. Add an explicit **pronunciation-guide rule** for any target word where script ≠ native script, with examples.
5. Add test `tests/test_language_separation_prompts.py`:
   - Build system prompts with native=Hindi, target=Tamil → assert prompt contains "always teach/examples in Tamil" AND "always explain/hints in Hindi" AND "bracketed Hindi pronunciation guide after Tamil script words";
   - Do same for native=Bengali, target=Sanskrit.

---

## 2. MCQ + Suggestions in Roleplay Mode

**Files:**
- Backend:
  - [english_roleplay_service.py](file:///C:/Users/MIRZA%20COMPUTER/Documents/ExamSpark-Project/examspark_backend/app/services/english_roleplay_service.py)
  - [english_roleplay_prompt.py](file:///C:/Users/MIRZA%20COMPUTER/Documents/ExamSpark-Project/examspark_backend/app/constants/english_roleplay_prompt.py)
  - [english_roleplay.py](file:///C:/Users/MIRZA%20COMPUTER/Documents/ExamSpark-Project/examspark_backend/app/routers/english_roleplay.py)
- Frontend:
  - [roleplay_screen.dart](file:///C:/Users/MIRZA%20COMPUTER/Documents/ExamSpark-Project/examspark_frontend/lib/presentation/screens/english_practice/roleplay_screen.dart)
  - [lecture_service.dart](file:///C:/Users/MIRZA%20COMPUTER/Documents/ExamSpark-Project/examspark_frontend/lib/core/services/lecture_service.dart) (SSE `done` event)

**Steps:**
1. **Prompt layer**: Append the exact MCQ instruction block to roleplay system prompt (same guardrails: emit only every 2–4 turns, never on opening greeting, never mixed with `<<PRACTICE_QUESTION>>`, never identical to either of the last 2 questions).
2. **Service layer — roleplay `start()`**: After `opening = await chat._call_model(...)`, run `clean, suggestions, mcq = chat._split_and_extract(opening); opening = clean or '…'`; attach `suggestions` and `mcq` to the returned `start()` dict. Expect mcq to be null on opening (as per prompt rule).
3. **Service layer — `send_turn()`**: Same. After `reply = await chat._call_model(...)` → `_split_and_extract`, persist the `clean` reply as assistant message, include `suggestions` and `mcq` keys in the return dict.
4. **Service layer — streaming `_roleplay_sse_events` / SSE done event**: In the router's final `done` event (right after streaming completes), emit `mcq` and `suggestions` keys so Flutter can surface them after the voice turn finishes. The JSON fallback path (`send_turn`) must also return the same keys.
5. **Flutter — `RoleplayVoiceScreen` layout change**: Refactor `Column(mainAxisAlignment: MainAxisAlignment.center)` to a `Stack` with a draggable/expandable bottom sheet or bottom-positioned "Practice panel" that appears only when mcq is present. Keep the central moon + timer visible. New layout:
   - Center stack (moon, hint, timer, back/exit buttons) unchanged.
   - `Positioned(left: 0, right: 0, bottom: 0)`: wrap inside `AnimatedSize` + `SafeArea` so it slides up when data arrives.
   - Inside: optional suggestions chips (horizontal Wrap, small chips, same styling as chat screen) → then the MCQ card widget (reuse the styling from `_practiceMcqPanel` in chat screen, adapt colors to roleplay's dark theme).
6. **MCQ tap semantics in roleplay**: Tapping an MCQ option in roleplay should:
   - Send it as a normal user **text** turn via `sendRoleplayTurn(transcript: optionText)` (need a new lightweight non-audio turn endpoint `turn/text` — roleplay currently only has audio endpoints) OR re-use chat's logic if endpoint exists;
   - OR (cheaper / per spec emphasis on voice-first): show a snackbar "Speak your answer now, or tap to send this one" and let tapping trigger a mic-off then text submit of the chosen option.
7. **Free-form answer path in roleplay (text)**: Add a **collapsible textfield** at the bottom of the panel so the user can also type the answer (per spec this is never forced quiz). Submitting it → calls the text turn endpoint OR triggers recording-start after setting it as prefilled text.
8. **Parse MCQ from API responses**:
   - `startEnglishRoleplay` → extract `suggestions` and `mcq`.
   - SSE `done` event → extract `suggestions` and `mcq` from the event map (already in `streamEnglishRoleplayAudio` callback).
   - Fallback JSON turn → extract `suggestions` and `mcq`.
9. **State management**: `_suggestions` (List<String>), `_currentMcq` (_PracticeMcq?), clear before each turn; store as state.
10. **Test `tests/test_roleplay_mcq.py`**: Mock `_call_model` to return `Hello there! <<PRACTICE_MCQ>>{"question":"வணக்கம் (Vanakkam) means?","options":["Hi","Bye","Eat"],"correct_option":0}<</END_PRACTICE_MCQ>>…<<SUGGESTIONS>>…` on roleplay start+turn — assert:
    - `start()` response has `opening_reply` cleaned of markers, contains `mcq` map, and `suggestions` list;
    - `send_turn()` response has `reply` cleaned, contains `mcq` and `suggestions`;
    - bad JSON in MCQ block is salvaged via existing fallback;
    - opening never contains MCQ when prompt explicitly forbids it (mock assert).

---

## 3. AI-Always-Goes-First + Opening Non-Genericness Hardening

**Files:**
- [english_roleplay_service.py](file:///C:/Users/MIRZA%20COMPUTER/Documents/ExamSpark-Project/examspark_backend/app/services/english_roleplay_service.py) `start()`
- [english_roleplay_prompt.py](file:///C:/Users/MIRZA%20COMPUTER/Documents/ExamSpark-Project/examspark_backend/app/constants/english_roleplay_prompt.py)
- [roleplay_screen.dart](file:///C:/Users/MIRZA%20COMPUTER/Documents/ExamSpark-Project/examspark_frontend/lib/presentation/screens/english_practice/roleplay_screen.dart) (UI validation)

**Steps:**
1. **Harden roleplay opening prompt instruction** — instead of the current one-liner, use a detailed block:
   - First line MUST be an **in-character, casual, scenario-specific greeting** in target language: NO "Hello, how can I help you today?", NO "Welcome to this roleplay", NO mentioning AI/chat/practice/lesson/scenario setup.
   - Example non-generic openings for reference in the prompt for 3 scenarios:
     - Restaurant (waiter): "Good evening! Table for two, or did you already book one?" (in target, + follow-up)
     - Friends at cafe: "Hey! I got here two minutes ago — did you find the place okay?" (in target)
     - Job interviewer: "Thanks for coming in today. Could you start by telling me a little about yourself?" (in target)
   - Require ONE follow-up easy question, then STOP.
2. **Service-layer guard**: `start()` will do a basic sanity check on the returned `opening` text:
   - If it contains blacklisted phrases `{"hello, how can i help", "welcome to this", "how may i assist", "today we will practice", "this is a roleplay", "let's begin the lesson" }` → regenerate once with stronger negative prompt; if second fail still, use a hand-written scenario-specific fallback.
3. **Only one turn, then wait**: Already guaranteed by `start()` → returns after a single assistant insert and no further messages; verify by test: start() persists exactly 1 message (role=assistant) and returns. Flutter already plays TTS of opening → then mic waits for user.
4. **Capture 2–3 real opening samples for review**: In `tests/` create a `test_roleplay_openings_live.py` test (marked `@pytest.mark.live`, skipped without `OPENROUTER_API_KEY`) that:
   - Starts 3 sessions for scenarios "Friends", "Restaurant", "Interview"
   - Prints and asserts no generic blacklisted phrase
   - Asserts end with a "?" (has follow-up question)
   - Returns in the report for human review.
5. **UI safety-net**: RoleplayVoiceScreen currently shows the opening as a line of text; keep `_openingReply` displayed throughout first listening so even if TTS fails, AI content is visibly "first".

---

## 4. NEW: Learn & Use Learner's Name

**Files:**
- DB schema (no migration engine yet, so schema-only doc + optional SQL):
  - `schema.sql` → `english_learning_memory` table, add column
- Backend:
  - [english_learning_memory_service.py](file:///C:/Users/MIRZA%20COMPUTER/Documents/ExamSpark-Project/examspark_backend/app/services/english_learning_memory_service.py)
  - [english_chat_prompt.py](file:///C:/Users/MIRZA%20COMPUTER/Documents/ExamSpark-Project/examspark_backend/app/constants/english_chat_prompt.py)
  - [english_roleplay_prompt.py](file:///C:/Users/MIRZA%20COMPUTER/Documents/ExamSpark-Project/examspark_backend/app/constants/english_roleplay_prompt.py)
  - Also: check existing `profiles.full_name` / `student_profiles` lookup — reuse this first!
- Tests:
  - `tests/test_learner_name.py`

**Steps:**
1. **Preferred name source FIRST (no new storage if avoidable)**:
   - `english_learning_memory_service.load_memory(user_id)` → add a 2-step lookup:
     a. Try `profiles` table `full_name` (the column already exists — schema line 16)
     b. Else try `student_profiles.full_name` joined by user_id
   - Return as `memory['preferred_name']` (read-only from profile tables — memory storage is fallback only)
   - **Fallback persistence**: add `learner_name` nullable column (TEXT, max 60 chars) to `english_learning_memory` table (add to schema.sql). Used ONLY if user types a name into chat but profile tables are empty.
2. **Memory formatting**: `format_memory_context` → append a top fact line when present: `"Learner's name: {name} — use it naturally in conversation occasionally, not every single turn, and NEVER repeat this meta-line."`
3. **Prompt rules (CHAT + ROLEPLAY, both prompts)**: Add a "Learner's name" subsection:
   - Early in a new session (turn 1–3), IF the name is still unknown, casually ask ONCE in the learner's native language, in natural casual chat flow that fits the scenario (not a form field question). Examples for prompt:
     - Chat-mode teacher (Hindi native): "बताइए, आपका नाम क्या है? ताकि आपसे बात करते समय आपको नाम से पुकार सकूँ।"
     - Roleplay "Friends" (Bengali native): "ওহে, আমি রিয়া — তোমার নাম কি বলো?"
     - If learner skips or doesn't give a name, drop it — never ask again in that session.
   - Once known: address the learner by name occasionally (roughly every 4th–6th turn, or to open a warm encouragement/correction). Natural like a friend/teacher. Not a formality. NEVER stuff it into every single reply (that's forbidden as robotic).
   - If the learner corrects the name mid-session, update memory with the corrected name immediately and start using it.
4. **Extraction path**: After each turn, `update_from_turn` already runs a Qwen extract call — additionally try to detect a name if `learner_name` is not yet set:
   - Look for a lightweight heuristic: assistant asked "what's your name?" in the recent turns, and user's reply contains a single first-name-like token (1–2 words, capitalized, no sentence punctuation) → if so, write it to `english_learning_memory.learner_name`.
   - For robustness: add a 2-shot JSON extraction of `{ "learner_name": string|null }` into the existing `update_from_turn` call only when unknown currently (to save tokens, do not extract every turn when known).
5. **Roleplay scenario-aware**: Scenario-specific opening may naturally include the name ask when appropriate (if name is unknown and roleplay's first 2 turns allow, the system prompt should encourage weaving it in; if it doesn't fit scenario e.g. "stranger at market" skip).
6. **Tests**:
   - Test A (profile lookup): fake profiles row with `full_name='Riya'` → `load_memory()` → `preferred_name == 'Riya'`, format_memory_context mentions `Learner's name: Riya`.
   - Test B (fallback storage): fake empty profile → memory upsert `learner_name='Arjun'` via extraction helper → `load_memory().learner_name == 'Arjun'` next call.
   - Test C (prompt rules): Build chat prompt with name unknown → contains "ask once early in native language" + "never ask more than once if skipped". Build with name=Riya → contains "use naturally occasionally, not every turn".
   - Test D (extraction heuristic): last assistant text `आपका नाम क्या है?`, user text `"मेरा नाम सौरभ है।"` → helper extracts `"Saurabh"` (or Hindi spelling — whatever is said in native script/pronunciation is kept).

---

## 5. File Inventory & Edit Order

| Order | File | Action |
|---|---|---|
| 1 | `app/constants/english_chat_prompt.py` | Add explicit language-boundary section, pronunciation rule, learner-name ask+use rules |
| 2 | `app/constants/english_roleplay_prompt.py` | Same language-boundary, add MCQ block, harden non-generic opening examples, add learner-name rules |
| 3 | `app/services/english_learning_memory_service.py` | Profile → memory name lookup, `learner_name` fallback column in upsert, format_memory_context includes name line, name extraction in `update_from_turn` (conditional when unknown) |
| 4 | `schema.sql` | Add optional `learner_name TEXT` column to `english_learning_memory` |
| 5 | `app/services/english_roleplay_service.py` | Split-and-extract mcq+suggestions in `start()` and `send_turn()`; opening blacklist sanity-check + 1-time regenerate; clean text persisted |
| 6 | `app/routers/english_roleplay.py` | Add `turn/text` endpoint (calls `send_turn`); SSE `done` event append `mcq`/`suggestions` |
| 7 | `lib/core/services/lecture_service.dart` | Add `sendEnglishRoleplayTurn(sessionId, transcript)` → `/turn/text`; update stream done-parse to surface `mcq`/`suggestions` |
| 8 | `lib/presentation/screens/english_practice/roleplay_screen.dart` | State fields `_suggestions`, `_currentMcq`, parse them from start/fallback/stream done; add bottom-positioned practice panel with chips + MCQ card, collapsible textfield for free-form answer, wire MCQ tap → text turn endpoint |
| 9 | Test suite | `test_language_separation_prompts.py`, `test_roleplay_mcq.py`, `test_roleplay_openings_live.py` (skipped offline), `test_learner_name.py` |

---

## 6. Dependencies / Considerations

- **No new storage engine required** for names — reuse existing `profiles/student_profiles.full_name` columns as primary source; fallback to new column in the already-existing `english_learning_memory` table (consistent with memory service design).
- **Roleplay voice-first constraint**: MCQ UI is additive, not a layout break. Added as an animated bottom sheet/positioned widget; microphone flow remains the primary path. Text-turn endpoint is a small new API surface.
- **LLM cost**: Extra prompt tokens (~400) across both prompts + conditional name-extraction call only when name is unknown (≈ 1 call per user, not per turn); overall costs don't change materially.
- **Streaming**: SSE only needs final `done` event extended (audio chunks unchanged).

---

## 7. Risk Handling

| Risk | Mitigation |
|---|---|
| LLM generates generic openings despite prompt | Second-pass regenerate + hand-written scenario fallbacks; live test prints output pre-merge for human review |
| Roleplay adds markers that TTS speaks aloud | `_split_and_extract` runs BEFORE persisting assistant message AND before calling TTS — spoken audio is always cleaned text |
| User types name in non-ASCII native script → stored incorrectly | Store the exact string the user typed (no transliteration); memory DB is TEXT, UTF-8 safe |
| Over-use of name feels robotic | Prompt explicitly says every 4–6 turns max; tests assert presence of "not every turn" in prompt; offline tests verify at least one "don't every turn" rule line |
| MCQ in roleplay conflicts with voice flow (listening interrupted) | Panel appears AFTER SSE done event (AI has finished speaking). Tapping an option triggers a normal text turn, which then re-arms mic normally |
| Schema.sql change requires DB migration | Column is nullable + only read if present; upsert via `english_learning_memory_service` safely omits the column until added. Document as optional manual SQL run |
