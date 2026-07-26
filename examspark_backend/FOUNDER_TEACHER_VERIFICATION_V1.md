# Founder — Teacher Verification v1 (AI Soft + Tavily)

Locked: [`TEACHER_PLATFORM.md`](../TEACHER_PLATFORM.md) §1c

## What was coded

- SQL: [`teacher_verification_v1_migration.sql`](teacher_verification_v1_migration.sql)
- API: `POST /api/v1/teachers/verify-certificate` (multipart `file`, optional `title`)
  - Qwen3-VL soft score (photocopy OK; AI-fake / gov ID / tamper)
  - Duplicate `certificate_hash` check
  - **Tavily** soft institution web check (`feature=teacher_verification`) — ± few points only
- Flutter: Teacher Dashboard → Profile → **Get Verified**

≥90% → `verification_status=verified` → Trusted badge  

**Minimum cert level:** Class **12 / 12th pass** or higher (diploma, degree, B.Ed…).  
Class 10 / below **rejected** (AI + score cap). After Trusted success → no need to re-run AI.
&lt;90% → message + Contact Support (`support@examspark.app`)

## Manual setup

### 1. SQL (required)

Supabase → SQL Editor → run [`teacher_verification_v1_migration.sql`](teacher_verification_v1_migration.sql)

### 2. Backend `.env`

Already used keys:

- `OPENROUTER_API_KEY` — required for vision  
- `TAVILY_API_KEY` — optional but recommended (soft institution check). Same key as Ask AI Tavily ([`FOUNDER_TAVILY.md`](FOUNDER_TAVILY.md))

Restart FastAPI after env change.

### 3. Flutter

Hot restart (**R**). `API_BASE_URL` must point at running backend.

## Smoke

1. Teacher Dashboard → **Get Verified**  
2. Upload a clear education certificate (or photocopy) — **min Class 12**  
3. Score ≥90 → badge next to name
4. Blurry / random photo → &lt;90 + Contact Support  

## Tavily role (soft)

After OCR extracts institution name → Tavily search  
- Found → small score boost  
- Not found → tiny soft penalty (does not alone deny badge)  
- Missing `TAVILY_API_KEY` → skip Tavily, vision-only  

Trust links (Website/LinkedIn/…) do **not** affect score.
