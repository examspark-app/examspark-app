"""GlowGuide research cache: RAG first, Tavily only on targeted cache misses."""
from __future__ import annotations

import hashlib
import logging
import re
from datetime import datetime, timedelta, timezone
from typing import Any

from app.services.embedding_service import EmbeddingError, embed_query, embed_texts
from app.services.supabase_admin import get_supabase_admin
from app.services.tavily_service import TavilySearchResult, tavily_search

logger = logging.getLogger(__name__)
_CACHE_TTL_DAYS = 30
_MATCH_THRESHOLD = 0.68

_RESEARCH_TERMS = re.compile(
    r"(?i)\b(research|study|studies|evidence|clinical|trial|journal|pubmed|"
    r"science|scientific|ingredient|ingredients|active|concentration|safe|safety|"
    r"effective|efficacy|formulation|formula|changed|latest|current|new|updated|"
    r"recent|available|availability|product|label)\b"
)
_CURRENT_TERMS = re.compile(r"(?i)\b(latest|current|new|updated|recent|availability|changed)\b")

_PRODUCT_BRANDS = re.compile(
    r"(?i)\b(cerave|cetaphil|minimalist|ordinary|neutrogena|mamaearth|sebamed|"
    r"fair\s*(?:&|and)?\s*lovely|glow\s*(?:&|and)?\s*lovely|lakme|olay|loreal|"
    r"johnson|johnsons|bioderma|derma\s*co|dot\s*&\s*key|la\s*roche|aveeno|"
    r"biore|cosrx|innisfree|himalaya|nivea|dove|ponds|garnier|plum|dr\s*sheths|"
    r"simple|clean\s*&\s*clear|vaseline|aquaphor|eucerin|laneige|vanicream)\b"
)
_PRODUCT_TYPES = re.compile(
    r"(?i)\b(cream|serum|cleanser|moisturizer|moisturiser|lotion|sunscreen|"
    r"shampoo|conditioner|face\s*wash|facewash|toner|gel|ointment|balm|"
    r"body\s*wash|soap|micellar|essence|night\s*cream|day\s*cream)\b"
)
_PRODUCT_VERIFY_CUES = re.compile(
    r"(?i)\b(is\s+this|is\s+it|check|review|ingredients?\s+of|suit\s+for|good\s+for|safe\s+for|can\s+i\s+use)\b"
)


def is_product_query(query: str) -> bool:
    """Detect if the query mentions a specific cosmetic brand or product."""
    text = (query or "").strip()
    if len(text) < 5:
        return False
    if bool(_PRODUCT_BRANDS.search(text)):
        return True
    return bool(_PRODUCT_TYPES.search(text)) and (
        bool(_RESEARCH_TERMS.search(text)) or bool(_PRODUCT_VERIFY_CUES.search(text))
    )


def is_targeted_research_query(query: str) -> bool:
    """Trigger research for scientific questions OR specific product checks."""
    text = (query or "").strip()
    if len(text) < 6:
        return False
    if is_product_query(text):
        return True
    return len(text) >= 12 and bool(_RESEARCH_TERMS.search(text))


def _normalized_query(query: str) -> str:
    return re.sub(r"\s+", " ", (query or "").strip().lower())[:500]


def _domains_for_query(query: str) -> list[str]:
    # Product verification needs cosmetic ingredient databases and brand sites, NOT PubMed exclusively
    if is_product_query(query):
        return [
            "incidecoder.com",
            "skincarisma.com",
            "ewg.org",
            "cir-safety.org",
            "paulaschoice.com",
            "cerave.com",
            "cetaphil.com",
            "beminimalist.co",
            "theordinary.com",
        ]

    # Trusted scientific / regulatory sources ONLY for clinical queries
    _TRUSTED_DOMAINS = [
        "pubmed.ncbi.nlm.nih.gov",  # Medical literature
        "nih.gov",                   # National Institutes of Health
        "fda.gov",                   # US FDA (safety, recalls)
        "who.int",                   # World Health Organization
        "dermnetnz.org",             # DermNet NZ (dermatology reference)
        "cir-safety.org",            # Cosmetic Ingredient Review
        "ewg.org",                   # Environmental Working Group (Skin Deep)
        "ncbi.nlm.nih.gov",          # National Library of Medicine
        "mayoclinic.org",            # Mayo Clinic (consumer health)
        "aad.org",                   # American Academy of Dermatology
        "oeko-tex.com",              # Textile safety certification
        "textileworld.com",          # Textile industry reference
    ]
    if _CURRENT_TERMS.search(query):
        return ["fda.gov", "nih.gov", "pubmed.ncbi.nlm.nih.gov", "who.int", "aad.org"]
    return _TRUSTED_DOMAINS


def _cache_is_fresh(row: dict[str, Any]) -> bool:
    expires = row.get("expires_at")
    if not expires:
        return True
    try:
        value = datetime.fromisoformat(str(expires).replace("Z", "+00:00"))
        return value > datetime.now(timezone.utc)
    except ValueError:
        return False

async def search_cached_research(query: str) -> dict[str, Any] | None:
    """Return the best fresh research hit, or None without external calls."""
    if not is_targeted_research_query(query):
        return None
    try:
        vector = await embed_query(query)
        result = get_supabase_admin().rpc(
            "match_glow_guide_research",
            {
                "query_embedding": vector,
                "match_threshold": _MATCH_THRESHOLD,
                "match_count": 3,
            },
        ).execute()
        rows = [r for r in (result.data or []) if _cache_is_fresh(r)]
        if not rows:
            return None
        return {
            "blocks": [str(r.get("content") or "") for r in rows],
            "sources": [
                {
                    "source_type": "glowguide_research_rag",
                    "similarity": r.get("similarity"),
                    "title": r.get("title"),
                    "url": r.get("source_url"),
                    "excerpt": str(r.get("content") or "")[:400],
                }
                for r in rows
            ],
            "used_web_search": False,
            "answer_source": "GLOWGUIDE_RAG",
        }
    except Exception as error:  # soft-fail until migration is deployed
        logger.warning("GlowGuide research RAG lookup failed: %s", error)
        return None

async def save_tavily_research(query: str, result: TavilySearchResult) -> None:
    """Embed and upsert cleaned evidence; failure never blocks the answer."""
    if not result.usable:
        return
    db = get_supabase_admin()
    normalized = _normalized_query(query)
    expires = datetime.now(timezone.utc) + timedelta(
        days=7 if _CURRENT_TERMS.search(query) else _CACHE_TTL_DAYS
    )
    rows = []
    for index, source in enumerate(result.sources_meta):
        content = result.snippets[index] if index < len(result.snippets) else ""
        url = (source.get("url") or "").strip()
        # Skip entries without a real source URL — without it we can't show
        # a domain reference chip on a future cache hit, so it's not worth
        # caching (the content alone, with no attributable source, isn't
        # useful evidence to resurface later).
        if not content or not url:
            continue
        key = hashlib.sha256(f"{normalized}|{url}".encode()).hexdigest()
        rows.append({
            "cache_key": key,
            "normalized_query": normalized,
            "topic_type": "current" if _CURRENT_TERMS.search(query) else "science_ingredient",
            "title": source.get("title") or "GlowGuide research",
            "source_url": url,
            "content": content[:6000],
            "fetched_at": datetime.now(timezone.utc).isoformat(),
            "expires_at": expires.isoformat(),
        })
    if not rows:
        return
    vectors = await embed_texts([row["content"] for row in rows])
    for row, vector in zip(rows, vectors):
        row["embedding"] = vector
    db.table("glow_guide_research_documents").upsert(rows, on_conflict="cache_key").execute()

async def tavily_research(query: str) -> dict[str, Any] | None:
    if not is_targeted_research_query(query):
        return None

    # For product queries, optimize search query to fetch actual official ingredients
    search_query = query
    if is_product_query(query) and "ingredient" not in query.lower():
        search_query = f"{query} full ingredients list official"

    result = await tavily_search(
        search_query,
        feature="glowguide_research",
        search_depth="basic",
        max_results=3,
        include_domains=_domains_for_query(query),
    )
    if not result.usable:
        return None

    header = (
        "VERIFIED PRODUCT INGREDIENTS & FORMULATION (Live Web Search Verification):\n"
        if is_product_query(query)
        else "Targeted research evidence:\n"
    )
    return {
        "blocks": [header + "\n\n---\n\n".join(result.snippets)],
        "sources": result.sources_meta,
        "used_web_search": True,
        "answer_source": "WEB",
        "tavily_result": result,
    }
