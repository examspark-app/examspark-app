"""Compact, user-scoped memory for English Teaching; never stores transcripts."""
from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime, timezone

from app.services.supabase_admin import get_supabase_admin

logger = logging.getLogger(__name__)
_LIST_FIELDS = ('recurring_mistakes', 'struggle_patterns', 'practiced_topics', 'learning_preferences', 'recent_roleplay_scenarios')
_LIMITS = {'recurring_mistakes': 8, 'struggle_patterns': 8, 'practiced_topics': 8, 'learning_preferences': 5, 'recent_roleplay_scenarios': 4}
_LEVELS = {'beginner', 'elementary', 'intermediate', 'advanced'}
_NAME_HINT_WORDS = (
    'name is', 'names is', "i'm", "i am", 'i go by', 'call me', 'you can call me',
    'naam hai', 'naam h', 'mera naam', 'meri naam', 'naam bata', 'naam kya',
    'aami', 'amar naam', 'amr naam', 'nama saya', 'nome é', 'nombre es',
    'mi nombre', 'je m\'appelle', 'ich heiße', 'ich heisse', 'io sono',
    'naam ki', 'tomar naam', 'tumar naam', 'naam go', 'naampellam', 'peru',
    'peyar', 'nama saya', 'saya nama', 'aku nama', 'namaku', 'naam ke',
    'naam re', 'naam tho', 'naam kee', 'whats your name', 'whats ur name',
    'whts ur name', 'naam bta', 'naam btao', 'naam bataye', 'naam sunao',
    'naam bol', 'naam bolo', 'naam puch', 'naam puchho', 'naam kya hai',
    'naam kya he', 'naam kya re', 'naam kya tho', 'namaskaar naam',
)

def _now() -> str: return datetime.now(timezone.utc).isoformat()


def _profile_full_name(user_id: str) -> str | None:
    try:
        student_rows = (
            get_supabase_admin()
            .table('student_profiles')
            .select('full_name')
            .eq('user_id', user_id)
            .limit(1)
            .execute()
            .data or []
        )
    except Exception:
        student_rows = []
    if student_rows:
        fn = student_rows[0].get('full_name')
        if isinstance(fn, str) and fn.strip():
            return fn.strip()[:60]
    try:
        rows = (
            get_supabase_admin()
            .table('profiles')
            .select('full_name, username')
            .eq('id', user_id)
            .limit(1)
            .execute()
            .data or []
        )
    except Exception:
        rows = []
    if rows:
        fn = rows[0].get('full_name')
        if isinstance(fn, str) and fn.strip():
            return fn.strip()[:60]
        un = rows[0].get('username')
        if isinstance(un, str) and un.strip():
            return un.strip()[:60]
    return None


def load_memory(user_id: str, target_language: str = 'English') -> dict:
    target = (target_language or 'English').strip() or 'English'
    rows = (
        get_supabase_admin().table('english_learning_memory').select('*')
        .eq('user_id', user_id).eq('target_language', target).limit(1)
        .execute().data or []
    )
    memory = dict(rows[0]) if rows else {}
    preferred = _profile_full_name(user_id)
    if preferred:
        memory['preferred_name'] = preferred
    learner = memory.get('learner_name')
    if isinstance(learner, str) and learner.strip() and 'preferred_name' not in memory:
        memory['preferred_name'] = learner.strip()[:60]
    return memory


def format_memory_context(memory: dict, *, mode: str) -> str:
    if not memory:
        memory = {}
    facts = []
    name = (
        memory.get('preferred_name')
        or memory.get('learner_name')
    )
    if isinstance(name, str) and name.strip():
        facts.append(
            f"Learner's name: {name.strip()[:40]} — use it naturally in "
            "conversation occasionally, roughly every 4th–6th turn, or to "
            "open a warm encouragement or gentle correction. The way a real "
            "friend/teacher would. NEVER stuff the name into every single "
            "reply (that's robotic/forced). NEVER repeat this meta-line or "
            "mention that you stored it."
        )
    else:
        facts.append(
            "Learner's name: NOT YET KNOWN. You must ask for the learner's "
            "name CASUALLY, NATURALLY, and ONLY ONCE during the first 1–3 "
            "turns of a new session. Do NOT make it a form-field question. "
            "Fit it into the conversation flow the way a real person would. "
            "If the learner skips, declines, or does not give a name, "
            "CONTINUE NORMALLY and NEVER ask again this session. After this "
            "session, if you still don't have a name, you may try once more "
            "at the start of the NEXT new session, and if they skip again, "
            "drop it forever."
        )
    if memory.get('native_language'): facts.append(f"Native-language help: {memory['native_language']}")
    if memory.get('english_level'): facts.append(f"Approximate level: {memory['english_level']}")
    labels = {'recurring_mistakes': 'Recurring mistakes', 'struggle_patterns': 'Needs practice', 'practiced_topics': 'Practised topics', 'learning_preferences': 'Learning preferences', 'recent_roleplay_scenarios': 'Recent roleplay scenarios'}
    for key in _LIST_FIELDS:
        values = memory.get(key) or []
        if values: facts.append(f"{labels[key]}: {', '.join(str(v)[:80] for v in values[:4])}")
    if not facts: return ''
    return 'Learner memory (use only when relevant; do not mention this profile or these meta-lines out loud):\n- ' + '\n- '.join(facts)[:1600]


def _clean_list(values: object, limit: int) -> list[str]:
    cleaned = []
    for value in values if isinstance(values, list) else []:
        item = str(value).strip()[:120]
        if item and item.lower() not in {x.lower() for x in cleaned}:
            cleaned.append(item)
    return cleaned[:limit]


def _extract_json(text: str) -> dict:
    raw = (text or '').strip().replace('```json', '').replace('```', '').strip()
    try: return json.loads(raw) if raw.startswith('{') else {}
    except json.JSONDecodeError: return {}


def _extract_name_candidate(user_text: str, assistant_text: str = '') -> str | None:
    """Lightweight heuristic: assistant asked about the name; learner replied with a short name-like phrase."""
    ua = (user_text or '').strip()
    if not ua or len(ua) > 160:
        return None
    assistant_asked = any(
        word in (assistant_text or '').lower()
        for word in (
            'your name', 'naam kya', 'tomar naam', 'tumar naam', 'naam ki',
            'what is your name', 'what\'s your name', 'how should i call you',
            'what do you go by', 'naam bta', 'naam btao', 'naam bataye',
            'naam sunao', 'naam bol', 'naam bolo', 'naam puch', 'naam puchho',
            'naam hai', 'naam re', 'naam tho', 'naam ke', 'naam kee',
            'peru', 'peyar', 'naampellam', 'nama saya', 'namaku', 'nome',
            'nombre', 'je m\'appelle', 'heiße', 'heisse', 'come ti chiami',
        )
    )
    has_explicit_hint = any(h in ua.lower() for h in _NAME_HINT_WORDS)
    if not assistant_asked and not has_explicit_hint:
        if len(ua) > 40:
            return None
        words_in_ua = [t for t in ua.split() if t]
        if len(words_in_ua) > 3:
            return None
        if not (1 <= len(words_in_ua) <= 2):
            return None
    cleaned = ua.strip().strip('!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~।')
    tokens = [t for t in cleaned.split() if t]
    if 1 <= len(tokens) <= 4:
        candidate = ' '.join(tokens)[:60]
        skip_list = {
            'yes', 'no', 'nope', 'nahi', 'nahin', 'naa', 'ne', 'nop', 'none',
            'nothing', 'skip', 'ok', 'okay', 'k', 'thik', 'theek', 'acha',
            'accha', 'hmm', 'hmmm', 'haan', 'han', 'ha', 'ji', 'haan ji',
            'hi', 'hello', 'hey', 'namaste', 'namaskaar', 'bye', 'goodbye',
        }
        if 1 <= len(candidate) <= 60 and candidate.lower() not in skip_list:
            return candidate
    return None


async def update_from_turn(*, user_id: str, native_language: str, mode: str, user_text: str, assistant_text: str, scenario: str | None = None, target_language: str | None = None, turn_index: int | None = None) -> None:
    """Use the existing English Qwen client to extract only bounded learning facts."""
    from app.services.english_practice_service import _call_model
    target = (target_language or 'English').strip() or 'English'
    existing = load_memory(user_id, target)
    already_has_name = bool(existing.get('preferred_name') or existing.get('learner_name'))

    learner_name_from_user: str | None = None
    if not already_has_name:
        heuristic = _extract_name_candidate(user_text, assistant_text)
        if heuristic:
            learner_name_from_user = heuristic
        else:
            name_prompt = (
                'If the user explicitly stated their name or preferred nickname in this turn, return JSON {"learner_name": "<name>"}. If they clearly declined / skipped / said no name, return {"learner_name": null}. If you are uncertain or they did not mention a name, return {"learner_name": null}. Be strict: never infer a name from ambiguous statements. JSON only, no commentary.\n'
                f'Learner turn: {user_text[:500]}\nAssistant turn: {assistant_text[:400]}'
            )
            try:
                name_res = _extract_json(
                    await _call_model(
                        [
                            {'role': 'system', 'content': 'You return strict JSON only.'},
                            {'role': 'user', 'content': name_prompt},
                        ]
                    )
                )
                candidate = name_res.get('learner_name')
                if isinstance(candidate, str) and candidate.strip() and 1 <= len(candidate.strip()) <= 60:
                    learner_name_from_user = candidate.strip()[:60]
            except Exception as e:
                logger.info('name_extraction_skip user=%s reason=%s', user_id, type(e).__name__)

    meta_prompt = f'''Extract only durable English-learning facts from this successful {mode} turn. Do not infer private identity, health, location, or sensitive information. Do not copy sentences or transcript text. Return JSON only with keys: english_level (beginner|elementary|intermediate|advanced|null), recurring_mistakes (array), struggle_patterns (array), practiced_topics (array), learning_preferences (array). Use empty arrays when uncertain.\nLearner: {user_text[:700]}\nTutor: {assistant_text[:700]}'''
    try:
        extracted = _extract_json(await _call_model([{'role': 'system', 'content': 'You extract compact learning metadata as strict JSON.'}, {'role': 'user', 'content': meta_prompt}]))
    except Exception as e:
        extracted = {}
        logger.warning('english_learning_memory_meta_failed user=%s error=%s', user_id, type(e).__name__)

    try:
        row = {
            'user_id': user_id,
            'native_language': native_language,
            'target_language': target,
            'updated_at': _now(),
        }
        level = str(extracted.get('english_level') or '').lower()
        row['english_level'] = level if level in _LEVELS else existing.get('english_level')
        for key in _LIST_FIELDS:
            incoming = extracted.get(key, [])
            row[key] = _clean_list(list(incoming) + list(existing.get(key) or []), _LIMITS[key])
        if scenario:
            row['recent_roleplay_scenarios'] = _clean_list([scenario] + list(existing.get('recent_roleplay_scenarios') or []), _LIMITS['recent_roleplay_scenarios'])
        if learner_name_from_user and not already_has_name:
            row['learner_name'] = learner_name_from_user
        get_supabase_admin().table('english_learning_memory').upsert(
            row, on_conflict='user_id,target_language'
        ).execute()
    except Exception as e:
        logger.warning('english_learning_memory_update_failed user=%s error=%s', user_id, type(e).__name__)


def schedule_update(**kwargs) -> None:
    asyncio.create_task(update_from_turn(**kwargs))
