"""AI response statuses — credits deduct on SUCCESS only (AI completed).

NOT_FOUND is reserved for HTTP/resource errors — never a billing exemption.
A completed Ask AI answer (including "not found in your notes") is SUCCESS.
"""
from __future__ import annotations

from typing import Literal

AiResponseStatus = Literal[
    "SUCCESS",
    "NOT_FOUND",
    "API_ERROR",
    "TIMEOUT",
    "NETWORK_ERROR",
    "VALIDATION_ERROR",
    "CANCELLED",
]

SUCCESS: AiResponseStatus = "SUCCESS"
NOT_FOUND: AiResponseStatus = "NOT_FOUND"
API_ERROR: AiResponseStatus = "API_ERROR"
TIMEOUT: AiResponseStatus = "TIMEOUT"
NETWORK_ERROR: AiResponseStatus = "NETWORK_ERROR"
VALIDATION_ERROR: AiResponseStatus = "VALIDATION_ERROR"
CANCELLED: AiResponseStatus = "CANCELLED"


def http_status_to_ai_status(status_code: int) -> AiResponseStatus:
    if status_code in (400, 402, 403):
        return VALIDATION_ERROR
    if status_code == 404:
        return NOT_FOUND
    if status_code == 504:
        return TIMEOUT
    if status_code >= 500:
        return API_ERROR
    return API_ERROR


def ai_error_payload(message: str, status: AiResponseStatus) -> dict:
    return {"message": message, "status": status}
