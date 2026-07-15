"""Server-side credit deduction — CREDIT_ECONOMY.md: "Deduct credits
server-side only." Wraps the `fn_deduct_credits` Postgres function
(schema.sql), which atomically checks balance + deducts + logs a
`credit_transactions` row, raising if the balance is insufficient.
"""
from app.services.supabase_admin import get_supabase_admin


class InsufficientCreditsError(Exception):
    def __init__(self, message: str):
        super().__init__(message)


def deduct_credits(
    user_id: str,
    amount: int,
    description: str,
    lecture_id: str | None = None,
    action: str | None = None,
) -> int:
    """Returns the new balance. Raises InsufficientCreditsError if the RPC
    rejects the deduction (insufficient balance or missing user)."""
    client = get_supabase_admin()
    try:
        response = client.rpc(
            "fn_deduct_credits",
            {
                "p_user_id": user_id,
                "p_amount": amount,
                "p_description": description,
                "p_lecture_id": lecture_id,
                "p_action": action,
            },
        ).execute()
    except Exception as e:  # noqa: BLE001 — Postgres RAISE EXCEPTION surfaces here
        raise InsufficientCreditsError(str(e)) from e

    return response.data
