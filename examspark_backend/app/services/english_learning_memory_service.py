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

def _now() -> str: return datetime.now(timezone.utc).isoformat()

def load_memory(user_id: str) -> dict:
    rows = get_supabase_admin().table('english_learning_memory').select('*').eq('user_id', user_id).limit(1).execute().data or []
    return rows[0] if rows else {}

def format_memory_context(memory: dict, *, mode: str) -> str:
    if not memory:
        return ''
    facts = []
    if memory.get('native_language'): facts.append(f"Native-language help: {memory['native_language']}")
    if memory.get('english_level'): facts.append(f"Approximate level: {memory['english_level']}")
    labels = {'recurring_mistakes': 'Recurring mistakes', 'struggle_patterns': 'Needs practice', 'practiced_topics': 'Practised topics', 'learning_preferences': 'Learning preferences', 'recent_roleplay_scenarios': 'Recent roleplay scenarios'}
    for key in _LIST_FIELDS:
        values = memory.get(key) or []
        if values: facts.append(f"{labels[key]}: {', '.join(str(v)[:80] for v in values[:4])}")
    if not facts: return ''
    return 'Learner memory (use only when relevant; do not mention this profile):\n- ' + '\n- '.join(facts)[:1400]

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

async def update_from_turn(*, user_id: str, native_language: str, mode: str, user_text: str, assistant_text: str, scenario: str | None = None) -> None:
    """Use the existing English Qwen client to extract only bounded learning facts."""
    from app.services.english_practice_service import _call_model
    prompt = f'''Extract only durable English-learning facts from this successful {mode} turn. Do not infer private identity, health, location, or sensitive information. Do not copy sentences or transcript text. Return JSON only with keys: english_level (beginner|elementary|intermediate|advanced|null), recurring_mistakes (array), struggle_patterns (array), practiced_topics (array), learning_preferences (array). Use empty arrays when uncertain.\nLearner: {user_text[:700]}\nTutor: {assistant_text[:700]}'''
    try:
        extracted = _extract_json(await _call_model([{'role': 'system', 'content': 'You extract compact learning metadata as strict JSON.'}, {'role': 'user', 'content': prompt}]))
        existing = load_memory(user_id)
        row = {'user_id': user_id, 'native_language': native_language, 'updated_at': _now()}
        level = str(extracted.get('english_level') or '').lower()
        row['english_level'] = level if level in _LEVELS else existing.get('english_level')
        for key in _LIST_FIELDS:
            incoming = extracted.get(key, [])
            if key == 'recent_roleplay_scenarios' and scenario: incoming = [scenario]
            row[key] = _clean_list(list(incoming) + list(existing.get(key) or []), _LIMITS[key])
        if scenario:
            row['recent_roleplay_scenarios'] = _clean_list([scenario] + list(existing.get('recent_roleplay_scenarios') or []), _LIMITS['recent_roleplay_scenarios'])
        get_supabase_admin().table('english_learning_memory').upsert(row, on_conflict='user_id').execute()
    except Exception as e:  # Memory must never fail a teaching turn.
        logger.warning('english_learning_memory_update_failed user=%s error=%s', user_id, type(e).__name__)

def schedule_update(**kwargs) -> None:
    asyncio.create_task(update_from_turn(**kwargs))
