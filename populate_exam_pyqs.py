"""
ExamSpark — exam_pyqs Auto-Populator (ONE-TIME RUN)
-----------------------------------------------------
Copyright-safe: stores ONLY exam/year/subject/chapter/class_level/country/
exam_category/weightage_stars/topic_label + embedding. NEVER stores the
original question text, options, or answer key (PROJECT_CORE_RULES §6).

Reuses existing project APIs:
    - Tavily          (web search, no domain restriction)
    - Qwen3 (chat)     via OpenRouter -> AI_CHAT_MODEL   (filter + structure)
    - OpenAI embedding via OpenRouter -> AI_EMBEDDING_MODEL (1536-dim, matches
      exam_pyqs.embedding vector(1536))
    - Supabase         (storage)

Run (VS Code terminal, whenever needed):
    python populate_exam_pyqs.py

Install once:
    pip install requests beautifulsoup4 pdfplumber openai supabase python-dotenv tavily-python

.env (already exists in your project, same variable names):
    TAVILY_API_KEY=...
    OPENROUTER_API_KEY=...
    SUPABASE_URL=...
    SUPABASE_KEY=...
    AI_CHAT_MODEL=qwen/qwen3-30b-a3b-instruct-2507
    AI_EMBEDDING_MODEL=openai/text-embedding-3-small
"""

import os
import io
import json
import time
import requests
from bs4 import BeautifulSoup
import pdfplumber
from openai import OpenAI
from supabase import create_client
from tavily import TavilyClient
from dotenv import load_dotenv

load_dotenv()

# ============================== CONFIG ==============================

TABLE = "exam_pyqs"

# Scope for THIS run — Pakistan/Nepal added later in a separate run
COUNTRIES = ["India", "Bangladesh"]
EXAM_CATEGORIES = ["board exam", "competitive exam", "job exam"]
YEARS = list(range(2015, 2025))  # 2015–2024, edit as needed

# ---------------------------- HARD LIMITS (medium scale) ----------------------------
MAX_SEARCH_CALLS_TOTAL = 150   # ~150 Tavily credits (well under free 1000/month)
MAX_RESULTS_PER_QUERY = 5
MAX_AI_CALLS_TOTAL = 150       # ~150 Qwen3 calls
MAX_ROWS_TOTAL = 180        # ~800 metadata rows inserted this run
# -----------------------------------------------------------------------------------

supabase = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])
tavily_client = TavilyClient(api_key=os.environ["TAVILY_API_KEY"])

ai_client = OpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key=os.environ["OPENROUTER_API_KEY"],
)

CHAT_MODEL = os.environ["AI_CHAT_MODEL"]
EMBED_MODEL = os.environ["AI_EMBEDDING_MODEL"]

counters = {"search_calls": 0, "ai_calls": 0, "rows_inserted": 0, "embed_calls": 0}


def limits_reached() -> bool:
    return (
        counters["search_calls"] >= MAX_SEARCH_CALLS_TOTAL
        or counters["ai_calls"] >= MAX_AI_CALLS_TOTAL
        or counters["rows_inserted"] >= MAX_ROWS_TOTAL
    )


# ============================== SEARCH ==============================

def search_web(query: str) -> list[dict]:
    if counters["search_calls"] >= MAX_SEARCH_CALLS_TOTAL:
        return []
    counters["search_calls"] += 1
    result = tavily_client.search(
        query=query,
        max_results=MAX_RESULTS_PER_QUERY,
        include_raw_content=True,
        search_depth="basic",  # 1 credit/call — keep cost predictable
    )
    return result.get("results", [])


def fetch_text_fallback(url: str) -> str:
    """Only used if Tavily didn't return raw_content for a result."""
    try:
        resp = requests.get(url, timeout=20, headers={"User-Agent": "Mozilla/5.0"})
        resp.raise_for_status()
    except Exception as e:
        print(f"    ⚠️ fetch failed: {e}")
        return ""

    if "pdf" in resp.headers.get("Content-Type", "") or url.lower().endswith(".pdf"):
        try:
            with pdfplumber.open(io.BytesIO(resp.content)) as pdf:
                return "\n".join(p.extract_text() or "" for p in pdf.pages)
        except Exception:
            return ""

    soup = BeautifulSoup(resp.text, "html.parser")
    for tag in soup(["script", "style", "nav", "footer", "header"]):
        tag.decompose()
    return soup.get_text(separator="\n", strip=True)


# ========================= AI: FILTER + STRUCTURE =========================

def extract_metadata_with_ai(raw_text: str, country: str, exam_category: str, year: int) -> list[dict]:
    """
    Reads raw page/PDF text and returns ONLY metadata rows — never the
    original question text, options, or answer. topic_label is a short
    descriptive cue (a few words), not a quote from the source.
    """
    if counters["ai_calls"] >= MAX_AI_CALLS_TOTAL or not raw_text or len(raw_text) < 100:
        return []
    counters["ai_calls"] += 1

    prompt = f"""Neeche diya gaya text {country} ke {exam_category} ({year}) se related
previous-year-question content ho sakta hai. Isme kai alag subjects/classes/topics
ka mix ho sakta hai.

IMPORTANT — COPYRIGHT RULE:
- Kabhi bhi original question text, options, ya answer verbatim copy MAT karo.
- "topic_label" sirf ek CHHOTA descriptive cue hai (max ~12 words) — jaise
  "NEET 2022 biology human heart circulation physiology" — paper se quote NAHI.

Is content mein jitne bhi distinct subject/class/topic combinations milein,
har ek ke liye ek row banao, is EXACT JSON array format mein, koi extra text nahi:

[
  {{
    "exam": "e.g. CBSE / NEET / JEE / SSC HSC / Matric / Railway RRB / Banking IBPS / State Board",
    "year": {year},
    "subject": "e.g. Physics",
    "chapter": "e.g. Laws of Motion",
    "class_level": "e.g. 10, 12, or null if not a school-class exam",
    "weightage_stars": 1-5 (estimate: how frequently this topic appears in this exam),
    "topic_label": "short descriptive cue, NOT a quote, max ~12 words"
  }}
]

Agar content mein koi valid, relevant PYQ info na mile, [] return karo.

TEXT:
{raw_text[:12000]}
"""
    try:
        response = ai_client.chat.completions.create(
            model=CHAT_MODEL,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.2,
        )
        raw = response.choices[0].message.content.strip()
        raw = raw.replace("```json", "").replace("```", "").strip()
        rows = json.loads(raw)
        for r in rows:
            r["country"] = country
            r["exam_category"] = exam_category
        return rows
    except Exception as e:
        print(f"    ⚠️ AI extraction failed: {e}")
        return []


# ============================== EMBEDDING ==============================

def generate_embedding(text: str) -> list[float] | None:
    if counters["embed_calls"] >= MAX_AI_CALLS_TOTAL * 2:  # soft secondary cap
        return None
    counters["embed_calls"] += 1
    try:
        resp = ai_client.embeddings.create(model=EMBED_MODEL, input=text)
        return resp.data[0].embedding
    except Exception as e:
        print(f"    ⚠️ embedding failed: {e}")
        return None


# ============================== DEDUPE + INSERT ==============================

def topic_label_exists(topic_label: str) -> bool:
    existing = (
        supabase.table(TABLE)
        .select("id")
        .eq("topic_label", topic_label)
        .execute()
    )
    return bool(existing.data)


def insert_row(row: dict):
    remaining = MAX_ROWS_TOTAL - counters["rows_inserted"]
    if remaining <= 0:
        return

    topic_label = row.get("topic_label")
    if not topic_label or not row.get("subject") or not row.get("exam"):
        return

    if topic_label_exists(topic_label):
        print(f"    ⏭️  duplicate skipped: {topic_label[:50]}")
        return

    embedding = generate_embedding(topic_label)
    if embedding is None:
        return

    payload = {
        "exam": row.get("exam"),
        "year": row.get("year"),
        "subject": row.get("subject"),
        "chapter": row.get("chapter"),
        "class_level": row.get("class_level"),
        "country": row.get("country"),
        "exam_category": row.get("exam_category"),
        "weightage_stars": row.get("weightage_stars", 3),
        "topic_label": topic_label,
        "embedding": embedding,
    }

    try:
        supabase.table(TABLE).insert(payload).execute()
        counters["rows_inserted"] += 1
        print(f"    ✅ inserted ({counters['rows_inserted']}/{MAX_ROWS_TOTAL}): {topic_label[:60]}")
    except Exception as e:
        print(f"    ⚠️ insert failed: {e}")


# ============================== MAIN ==============================

def main():
    print("🚀 Starting one-time exam_pyqs population run (India + Bangladesh)...\n")

    for country in COUNTRIES:
        if limits_reached():
            break
        for exam_category in EXAM_CATEGORIES:
            if limits_reached():
                break
            for year in YEARS:
                if limits_reached():
                    break

                query = f"{country} {exam_category} {year} previous year question papers all subjects"
                print(f"🔍 {query}")
                results = search_web(query)

                for r in results:
                    if limits_reached():
                        break
                    url = r.get("url", "")
                    text = r.get("raw_content") or fetch_text_fallback(url)
                    print(f"  → {url}")

                    rows = extract_metadata_with_ai(text, country, exam_category, year)
                    for row in rows:
                        if limits_reached():
                            break
                        insert_row(row)

                    time.sleep(1)  # politeness delay

    print("\n📊 SUMMARY")
    print(f"  Search calls used:  {counters['search_calls']}/{MAX_SEARCH_CALLS_TOTAL}")
    print(f"  AI calls used:      {counters['ai_calls']}/{MAX_AI_CALLS_TOTAL}")
    print(f"  Rows inserted:      {counters['rows_inserted']}/{MAX_ROWS_TOTAL}")
    print("\n✅ Run complete. No further action needed.")


if __name__ == "__main__":
    main()