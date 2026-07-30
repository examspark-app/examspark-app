# Invite link → direct Group page

## What you get

Share / QR link ab **dead page nahi** — Sonaxia app khulta hai aur **teacher group page** pe land hota hai.

| Who opens link | Lands on |
|----------------|----------|
| Student (logged in) | **Group Info** (join auto if needed) |
| Student (not logged in) | Login → phir group |
| Teacher (own group) | **Group Dashboard** |

## Link format

- **Local (abhi Chrome):** `http://localhost:8080/#/join/YOURCODE`
- **Live later:** `https://sonaxia.com/#/join/YOURCODE`

`YOURCODE` = group join code (e.g. `485022`), coupon alag cheez hai.

## New student (no account yet)

1. Invite link open → **Sign Up** screen (“Create a free account to open your teacher’s group”)
2. Account create (ya Google) → onboarding if needed
3. Phir **seedha teacher group** page

Invite code browser mein save rehta hai — email verify / Google redirect ke baad bhi group open hota hai.

## Test (2 min)

1. Flutter Chrome — **hot restart** (`R`)
2. Teacher: Share / Copy link (`#/join/...`)
3. **Incognito** ya logout Chrome tab → link paste
4. **Sign Up** → account banao → **Expected:** group page (Group Info)
5. Already logged-in teacher: own link → Group Dashboard


## Manual setup

Koi SQL / `.env` nahi.

Live `sonaxia.com` ke liye baad mein Cloudflare deploy — abhi local link se test karo.

## Rollback

Purane Share text mat use karo; naya Copy link lo after hot restart.
