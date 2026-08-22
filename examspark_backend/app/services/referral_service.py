from app.services.supabase_admin import get_supabase_admin


def get_referral_summary(user_id: str) -> dict:
    db = get_supabase_admin()
    user = db.table("users").select("referral_code").eq("id", user_id).single().execute().data or {}
    rows = db.table("referrals").select("id, referred_user_id, credits_given, status, created_at").eq(
        "referrer_id", user_id
    ).order("created_at", desc=True).limit(100).execute().data or []
    return {
        "code": user.get("referral_code") or "",
        "earned_credits": sum(int(row.get("credits_given") or 0) for row in rows if row.get("status") == "completed"),
        "referrals": rows,
    }


def redeem_referral(user_id: str, code: str) -> dict:
    result = get_supabase_admin().rpc(
        "redeem_referral", {"p_referred_user_id": user_id, "p_code": code}
    ).execute()
    return result.data or {"status": "rejected"}