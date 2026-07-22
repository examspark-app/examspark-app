# ExamSpark — Tavily web search (strict / last resort)

**Not a general web-search feature.** Only current-affairs when nothing else works.

## When Tavily runs (ALL must be true)

1. Route = `web_deferred` only (question_router soft hints)
2. LLM classifier says **YES** = genuine recent/current events (not syllabus)
3. RAG has **no** usable match AND PYQ bank has **no** match

Otherwise: honest “no reliable current information” — **no** Tavily call.

## Credits (ExamSpark)

| Mode | Normal Ask | With live web |
|------|------------|---------------|
| Normal | 5 | **10** |
| Deep | 12 | **20** |

UI shows: `Source: Live web search (current events)` + note why it cost more.

## Tavily free tier

- Sign up at [tavily.com](https://tavily.com) → free tier (~1,000 credits/month, no card)
- Copy API key
- Paste into backend `.env` only (never Flutter):

```env
TAVILY_API_KEY=tvly-xxxxxxxx
```

- Restart FastAPI after saving `.env`
- Search depth default = **basic** (1 Tavily credit)

## Logs (cost monitoring)

Backend log lines tagged `tavily_usage` — grep:

```powershell
# In the uvicorn terminal, look for:
tavily_usage feature=... usable=... tavily_credits=... skip_reason=...
```

## How to test

| # | Question | Expect |
|---|----------|--------|
| 1 | `Explain photosynthesis` | **No** Tavily; normal credits (5); Source Notes/Knowledge |
| 2 | `today's news` / current affairs with no notes match | Classifier YES → Tavily → **10** credits; Source Live web search |
| 3 | Current affairs but Tavily key missing | Honest fallback; log `skip_reason=not_configured` |

## Files

- `app/services/tavily_service.py` · `tavily_gate.py`
- `question_router.py` · Home AI · Ask AI
- `credit_costs.py` / `.dart`
