# Home / Ask — Answer intelligence (anti-template) Jul 26, 2026

## Problem
Answers felt like the **same template** every time (Direct Answer / Key Points…).

## Fix
1. Detect question intent: greeting · definition · how/why · compare · short/long exam · numerical · list.
2. **Understand first → answer that intent** (natural tutor prose).
3. Hard **anti-template** rule — no forced section skeleton.
4. Shared by **Home AI + Ask AI**.

File: `app/constants/answer_intelligence.py`

## Test
1. **Restart FastAPI**
2. New chat → `hi` → short friendly
3. `What is photosynthesis?` → natural short (no headers)
4. `Explain clearly…` → longer tutor style
5. `Difference between A and B` → compare style
6. Should **not** look like copy-paste sections every time

## Manual setup
- No SQL · No .env · Restart FastAPI
