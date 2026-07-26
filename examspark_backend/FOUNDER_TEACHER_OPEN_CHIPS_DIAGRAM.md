# Fix 3 problems — Teacher Library Open / chips / diagram

## 1. Diagram nahi dikhta — **SQL data**, Flutter bug nahi

TEST Sample Lecture seed mein `visual_payload_json = NULL` tha.

**Aapko abhi run karna hai** (Supabase → SQL Editor):

File: [`FOUNDER_FIX_SAMPLE_LECTURE_DIAGRAM.sql`](FOUNDER_FIX_SAMPLE_LECTURE_DIAGRAM.sql)

Expect: `UPDATE 1`  
Phir Open → Notes neeche / Visual tab pe diagram.

## 2. Full page Open — **coded**

Teacher Dashboard → My Library → **Open** → ab `/study_workspace` full page (popup nahi).

Hot restart (`R`).

## 3. Chips hide / scroll — **coded**

Study chips ab **Wrap** — multi-line (≈3 lines), sab dikhenge. Horizontal hide scroll hata diya.

Hot restart (`R`).

## Manual setup

| Step | Action |
|------|--------|
| 1 | Run [`FOUNDER_FIX_SAMPLE_LECTURE_DIAGRAM.sql`](FOUNDER_FIX_SAMPLE_LECTURE_DIAGRAM.sql) |
| 2 | Flutter hot restart |
| 3 | Open TEST lecture → diagram + full page + chips check |

No `.env` change.
