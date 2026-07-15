# Abhi ka Credit Economy (jo code mein chal raha hai)

> **Saved:** Jul 15, 2026  
> **Purpose:** Founder cheat sheet. Full detail: [`CREDIT_ECONOMY.md`](CREDIT_ECONOMY.md).

---

## Teen alag users (yaad rakho)

| Kaun | Kya milta hai |
|------|----------------|
| **Bina signup (Guest)** | Sirf **1 free prompt per device** (save hota hai — refresh se dobara nahi). Browser data clear kare to fir try ho sakta hai; asli guest AI pe server IP limit aayegi |
| **Signup → Free plan** | **50 credits** (signup grant). Ask/PDF/Photo inme se cut. Audio **₹499+** lock |
| **Paid plan** (₹199 / ₹499 / ₹999 / Teacher) | **Us plan ke credits** (1,500 / 3,500 / 8,000 / 16,000). **Free wale 50 alag se nahi milte** |

```text
Guest: 1 question → signup wall
Free signup: 50 credits pool
Paid: plan package only (no +50 Free stack)
```

---

## Plan unlock (features)

| Feature | Free | ₹199 | ₹499+ |
|---------|------|------|-------|
| Ask / PDF / Photo | credits | credits | credits |
| Audio record + upload | LOCK | LOCK | OK |
| Groups join | 0 | 1 | 3+ |

---

## Example tests

| # | Action | Expected |
|---|--------|----------|
| G1 | Logout / Guest → 1 sawal | Reply; 2nd → Sign up sheet |
| F1 | New signup Free | Balance **50** |
| F2 | Free Ask | −5 from 50 |
| P1 | Paid ₹199 user | Balance from **plan** (e.g. 1,500), not “50 + …” |
| A1 | Free/₹199 mic | Lock icon → ₹499 sheet |

**SQL signup 50:** run full [`credit_economy_free50_audio199_migration.sql`](examspark_backend/credit_economy_free50_audio199_migration.sql) once.

Flutter **`R`**. FastAPI restart for server audio ₹499 lock.
