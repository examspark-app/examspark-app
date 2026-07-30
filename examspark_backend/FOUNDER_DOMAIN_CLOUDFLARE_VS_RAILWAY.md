# Founder — Domain: Cloudflare vs Railway (Sonaxia)

## Short answer

| Cheez | Kahan |
|-------|--------|
| **Website + invite link** `https://sonaxia.com/join/CODE` | **Cloudflare** (Pages + DNS + your `.com`) |
| **FastAPI backend** (AI, coupons, credits) | **Railway** (later often `api.sonaxia.com`) |

Invite / QR / Share link = **Cloudflare web app**, Railway nahi.

## Deploy-time security (listed Jul 26 — not built yet)

| When | What |
|------|------|
| `start Railway deploy guide` | AI kill switch + rate limit (paid engine OFF if flood) |
| `start web deploy guide` | Cloudflare DDoS on `sonaxia.com` |

**Abhi local pe mat banao.**

## Invite link format (direct group land)

`https://sonaxia.com/#/join/485022`  
Local: `http://localhost:8080/#/join/485022`

Opens app → join if needed → **Group Info** (teacher group page).  
Teacher opening own link → Group Dashboard.


## Abhi local smoke

Link click se site nahi khulegi jab tak domain + deploy nahi.  
Students ke liye: **6-digit code** se Join.

## Baad mein aapke haath (jab ready)

1. Domain kharido: **sonaxia.com**  
2. Cloudflare → DNS → domain add  
3. Flutter Web → Cloudflare Pages deploy  
4. Optional: Railway custom domain `api.sonaxia.com` + `.env` `FASTAPI_BASE_URL`  
5. Deep link `/join/CODE` route smoke (web open → join screen)

Bolo `start web deploy guide` jab Cloudflare pe pehla deploy karna ho.
