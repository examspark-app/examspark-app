from app.services.supabase_admin import get_supabase_admin

MAX_ACCOUNTS_PER_DEVICE = 3


def account_count(device_id: str) -> int:
    value = device_id.strip()
    if not value:
        return 0
    result = get_supabase_admin().table("users").select("id", count="exact").eq(
        "device_id", value
    ).execute()
    return len(result.data or [])


def register(user_id: str, device_id: str) -> None:
    value = device_id.strip()
    if not value:
        return
    get_supabase_admin().table("users").update({"device_id": value}).eq(
        "id", user_id
    ).execute()