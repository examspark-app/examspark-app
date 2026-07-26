"""Teacher Verification v1 — soft AI (vision) + optional Tavily institution check.

Locked: TEACHER_PLATFORM.md §1c
- Photocopy of real education cert OK
- Fail AI-fake / duplicate / heavy edit / gov ID
- Confidence ≥ 90 → Trusted badge
- Tavily: soft web check that extracted institution/issuer looks real (no score-only links)
"""
from __future__ import annotations

import asyncio
import base64
import hashlib
import json
import logging
import re
from datetime import datetime, timezone

import httpx

from app.config import AIConfig
from app.services.qwen_service import _extract_json_object
from app.services.supabase_admin import get_supabase_admin
from app.services.tavily_service import log_tavily_usage, tavily_configured, tavily_search

logger = logging.getLogger(__name__)

# Same host as qwen/home_ai — api.openrouter.ai fails DNS on some Windows networks
# (Errno 11001 getaddrinfo) while openrouter.ai resolves fine.
_OR_URL = "https://openrouter.ai/api/v1/chat/completions"

_VERIFY_SYSTEM = (
    "You soft-verify an EDUCATION certificate image for ExamSpark teachers. "
    "Photocopy/scan of a REAL certificate is OK. "
    "Reject phone/desktop SCREENSHOTS of certificates (UI chrome, status bar, "
    "notification shade, browser frame, cropped screen capture). "
    "Reject government IDs (Aadhaar, PAN, Passport, Driving License). "
    "Detect AI-generated fakes, heavy photoshop/edit, and non-education docs. "
    "MINIMUM EDUCATION LEVEL (mandatory): accept only certificates that prove "
    "Class 12 / 12th pass / Higher Secondary / Intermediate OR higher "
    "(diploma, bachelor's, master's, B.Ed, teaching license, university degree). "
    "REJECT low-class / school certificates below 12th "
    "(Class 1–11, Class 10 / SSC alone, middle school, primary, nursery). "
    "Class 10 alone is NOT enough. "
    "Return ONLY JSON with keys:\n"
    '- "confidence": number 0-100 (overall soft authenticity)\n'
    '- "is_education_certificate": boolean\n'
    '- "is_government_id": boolean\n'
    '- "is_screenshot": boolean\n'
    '- "likely_ai_generated_fake": boolean\n'
    '- "likely_tampered": boolean\n'
    '- "is_photocopy_or_scan": boolean\n'
    '- "readability": number 0-100\n'
    '- "extracted_name": string or null\n'
    '- "certificate_type": short string (degree, diploma, teacher_certificate, board, training, other)\n'
    '- "certificate_subject": string or null\n'
    '- "institution_name": string or null (university/board/institute)\n'
    '- "education_level_detected": short string '
    '(e.g. class_10, class_12, diploma, bachelor, master, bed, other, unknown)\n'
    '- "meets_minimum_class_12": boolean '
    '(true only if Class 12 / HSC / Intermediate OR any higher qualification)\n'
    '- "reasons": array of short strings\n'
)

_SCREENSHOT_NAME_RE = re.compile(
    r"(screenshot|screen[_\s-]?shot|screen[_\s-]?capture|screenrecording|"
    r"snip(ping)?tool|capture\d+|img_\d{8}_\d+|screenshot_\d+)",
    re.IGNORECASE,
)

TRUSTED_THRESHOLD = 90.0


class TeacherVerificationError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.status_code = status_code


def _mime(filename: str | None) -> str:
    name = (filename or "").lower()
    if name.endswith(".png"):
        return "image/png"
    if name.endswith(".webp"):
        return "image/webp"
    if name.endswith(".pdf"):
        return "application/pdf"
    if name.endswith(".heic") or name.endswith(".heif"):
        return "image/heic"
    return "image/jpeg"


def _looks_like_screenshot_filename(filename: str | None) -> bool:
    if not filename:
        return False
    base = filename.replace("\\", "/").split("/")[-1]
    return bool(_SCREENSHOT_NAME_RE.search(base))


def _pdf_first_page_png(raw: bytes) -> bytes:
    """Rasterize PDF page 1 → PNG. Prefer pypdfium2 (Windows/Py3.14-friendly)."""
    # 1) pypdfium2 + Pillow
    try:
        import pypdfium2 as pdfium
        from io import BytesIO

        from PIL import Image

        doc = pdfium.PdfDocument(raw)
        if len(doc) < 1:
            raise TeacherVerificationError("PDF has no pages.")
        page = doc[0]
        bitmap = page.render(scale=1.5)
        pil = bitmap.to_pil()
        if pil.mode not in ("RGB", "L"):
            pil = pil.convert("RGB")
        buf = BytesIO()
        pil.save(buf, format="PNG")
        doc.close()
        return buf.getvalue()
    except TeacherVerificationError:
        raise
    except Exception as e1:
        logger.warning("pypdfium2 PDF render failed: %s", e1)

    # 2) pymupdf (fitz) — may fail DLL on some Python builds
    try:
        import fitz  # pymupdf

        doc = fitz.open(stream=raw, filetype="pdf")
        if doc.page_count < 1:
            raise TeacherVerificationError("PDF has no pages.")
        page = doc.load_page(0)
        pix = page.get_pixmap(matrix=fitz.Matrix(2, 2), alpha=False)
        png = pix.tobytes("png")
        doc.close()
        return png
    except TeacherVerificationError:
        raise
    except Exception as e2:
        logger.warning("pymupdf PDF render failed: %s", e2)
        raise TeacherVerificationError(
            "Could not read this PDF on the server. "
            "Try another PDF, or upload a clear JPG/PNG photo of the certificate. "
            f"({e2})",
            status_code=503,
        ) from e2


def _prepare_vision_image(raw: bytes, filename: str | None) -> tuple[bytes, str]:
    """Return (image_bytes, vision_filename). PDF → first page PNG."""
    name = (filename or "certificate.jpg").lower()
    if _looks_like_screenshot_filename(filename):
        raise TeacherVerificationError(
            "Screenshots are not allowed. Upload a photo, scan, or PDF of your education certificate."
        )
    if name.endswith(".pdf"):
        return _pdf_first_page_png(raw), "certificate_page1.png"
    # Images as-is (HEIC may fail on some vision models — user can re-export JPG)
    return raw, filename or "certificate.jpg"


def _downscale_for_vision(raw: bytes, filename: str | None) -> tuple[bytes, str]:
    """Shrink large photos before OpenRouter — biggest speed win (upload + AI)."""
    from io import BytesIO

    try:
        from PIL import Image

        img = Image.open(BytesIO(raw))
        if img.mode not in ("RGB", "L"):
            img = img.convert("RGB")
        elif img.mode == "L":
            img = img.convert("RGB")
        max_edge = 1280
        if max(img.size) > max_edge:
            img.thumbnail((max_edge, max_edge), Image.Resampling.LANCZOS)
        buf = BytesIO()
        img.save(buf, format="JPEG", quality=82, optimize=True)
        out = buf.getvalue()
        # Only use if smaller / reasonable
        if len(out) < len(raw) or max(img.size) <= max_edge:
            return out, "certificate_vision.jpg"
    except Exception as e:
        logger.warning("vision downscale skipped: %s", e)
    return raw, filename or "certificate.jpg"


def certificate_sha256(image_bytes: bytes) -> str:
    return hashlib.sha256(image_bytes).hexdigest()


def _clamp_score(n: float) -> float:
    return max(0.0, min(100.0, float(n)))


async def _vision_soft_analyze(
    image_bytes: bytes,
    filename: str | None,
    profile_full_name: str,
) -> dict:
    if not AIConfig.openrouter_configured():
        raise TeacherVerificationError(
            "OPENROUTER_API_KEY not configured on the server.",
            status_code=503,
        )

    mime = _mime(filename)
    b64 = base64.b64encode(image_bytes).decode("ascii")
    data_url = f"data:{mime};base64,{b64}"
    model = AIConfig.AI_VISION_FLASH_MODEL
    user_text = (
        f"Teacher profile name: {profile_full_name or '(unknown)'}. "
        "Soft-verify this document. Photocopy of real education cert is OK. "
        "Flag AI-created fakes, heavy edits, government IDs."
    )
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": _VERIFY_SYSTEM},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": user_text},
                    {"type": "image_url", "image_url": {"url": data_url}},
                ],
            },
        ],
        "temperature": 0.1,
        "max_tokens": 900,
        "response_format": {"type": "json_object"},
    }
    headers = {
        "Authorization": f"Bearer {AIConfig.OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
    }
    try:
        async with httpx.AsyncClient(timeout=55.0) as client:
            response = await client.post(_OR_URL, headers=headers, json=payload)
    except httpx.ConnectError as e:
        logger.exception("OpenRouter connect failed during teacher verify")
        raise TeacherVerificationError(
            "Cannot reach OpenRouter (network/DNS). Check internet, then retry. "
            f"Detail: {e}",
            status_code=503,
        ) from e
    except httpx.TimeoutException as e:
        raise TeacherVerificationError(
            "Verification timed out talking to AI. Retry in a minute.",
            status_code=504,
        ) from e
    if response.status_code != 200:
        raise TeacherVerificationError(
            f"Vision verify failed: {response.status_code} {response.text[:200]}",
            status_code=502,
        )
    data = response.json()
    content = (((data.get("choices") or [{}])[0].get("message") or {}).get("content")) or ""
    try:
        parsed = _extract_json_object(content) if isinstance(content, str) else content
        if isinstance(parsed, str):
            parsed = json.loads(parsed)
    except Exception as e:
        raise TeacherVerificationError(
            "Could not parse verification JSON from vision model.",
            status_code=502,
        ) from e
    if not isinstance(parsed, dict):
        raise TeacherVerificationError("Invalid verification response.", status_code=502)
    return parsed


def _name_soft_match(profile_name: str, extracted: str | None) -> bool:
    if not extracted or not profile_name:
        return True
    a = re.sub(r"[^a-z\s]", "", profile_name.lower()).strip()
    b = re.sub(r"[^a-z\s]", "", extracted.lower()).strip()
    if len(a) < 3 or len(b) < 3:
        return True
    if a in b or b in a:
        return True
    a_toks = [t for t in a.split() if len(t) >= 3]
    b_toks = set(b.split())
    if not a_toks:
        return True
    hits = sum(1 for t in a_toks if t in b_toks)
    return hits >= max(1, len(a_toks) // 2)


async def _tavily_institution_soft(institution: str | None) -> dict:
    """Soft web signal only — does not alone grant or deny badge."""
    name = (institution or "").strip()
    if not name or len(name) < 3:
        return {"applied": False, "delta": 0, "reason": "no_institution"}
    if not tavily_configured():
        log_tavily_usage(
            feature="teacher_verification",
            query=name,
            tavily_credits=0,
            usable=False,
            result_count=0,
            skip_reason="not_configured",
        )
        return {"applied": False, "delta": 0, "reason": "tavily_not_configured"}

    query = f"{name} education India university college board institute"
    result = await tavily_search(
        query,
        feature="teacher_verification",
        search_depth="basic",
        max_results=3,
    )
    if result.usable and result.raw_result_count > 0:
        return {
            "applied": True,
            "delta": 5.0,
            "reason": "institution_found_on_web",
            "snippets": result.snippets[:2],
        }
    # Soft only — don't crush score if web has nothing (small institutes)
    return {
        "applied": True,
        "delta": -3.0,
        "reason": "institution_not_found_soft",
        "snippets": [],
    }


def _finalize_score(vision: dict, profile_name: str, tavily_delta: float) -> tuple[float, list[str]]:
    reasons: list[str] = []
    raw = vision.get("confidence")
    try:
        score = float(raw if raw is not None else 50)
    except (TypeError, ValueError):
        score = 50.0

    if vision.get("is_screenshot") is True:
        score = min(score, 20.0)
        reasons.append("Screenshot not allowed — use photo/scan/PDF")
    if vision.get("is_government_id") is True:
        score = min(score, 35.0)
        reasons.append("Government ID not accepted")
    if vision.get("is_education_certificate") is False:
        score = min(score, 45.0)
        reasons.append("Not classified as education certificate")
    # Minimum Class 12 / 12th pass — reject Class 10 and below
    if vision.get("meets_minimum_class_12") is False:
        score = min(score, 25.0)
        level = vision.get("education_level_detected")
        level_txt = f" (detected: {level})" if isinstance(level, str) and level else ""
        reasons.append(
            "Low-class certificate not allowed — minimum Class 12 / 12th pass"
            f"{level_txt}"
        )
    if vision.get("likely_ai_generated_fake") is True:
        score = min(score, 40.0)
        reasons.append("Likely AI-generated fake")
    if vision.get("likely_tampered") is True:
        score = min(score, 50.0)
        reasons.append("Likely edited / tampered")
    readability = vision.get("readability")
    try:
        if readability is not None and float(readability) < 40:
            score = min(score, 55.0)
            reasons.append("Low readability")
    except (TypeError, ValueError):
        pass

    extracted = vision.get("extracted_name")
    if isinstance(extracted, str) and not _name_soft_match(profile_name, extracted):
        score -= 8.0
        reasons.append("Name on certificate does not closely match profile")

    # Photocopy of real cert is OK — small boost for honesty if model flags copy/scan
    if vision.get("is_photocopy_or_scan") is True and vision.get("likely_ai_generated_fake") is not True:
        score += 2.0
        reasons.append("Photocopy/scan of real cert accepted (soft)")

    score += tavily_delta
    if tavily_delta > 0:
        reasons.append("Institution found via web (Tavily soft +)")
    elif tavily_delta < 0:
        reasons.append("Institution weak on web (Tavily soft −)")

    for r in vision.get("reasons") or []:
        if isinstance(r, str) and r.strip():
            reasons.append(r.strip())

    return _clamp_score(score), reasons[:12]


async def verify_teacher_certificate(
    *,
    user_id: str,
    image_bytes: bytes,
    filename: str | None,
    title: str | None = None,
) -> dict:
    if not image_bytes or len(image_bytes) < 100:
        raise TeacherVerificationError("Certificate file required.")
    if len(image_bytes) > 12 * 1024 * 1024:
        raise TeacherVerificationError("File too large (max 12 MB).")

    image_bytes, filename = _prepare_vision_image(image_bytes, filename)

    db = get_supabase_admin()
    profile_rows = (
        db.table("teacher_profiles")
        .select("id, full_name, verification_status")
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )
    rows = profile_rows.data or []
    if not rows:
        raise TeacherVerificationError(
            "Create your teacher profile first (Dashboard → Edit Profile).",
            status_code=400,
        )
    profile = rows[0]
    teacher_id = profile["id"]
    full_name = (profile.get("full_name") or "").strip()

    digest = certificate_sha256(image_bytes)

    # Duplicate across other teachers
    dup = (
        db.table("teacher_certificates")
        .select("id, teacher_id")
        .eq("certificate_hash", digest)
        .neq("teacher_id", teacher_id)
        .limit(1)
        .execute()
    )
    if dup.data:
        now = datetime.now(timezone.utc).isoformat()
        db.table("teacher_profiles").update(
            {
                "verification_status": "unverified",
                "verification_score": 25,
                "verification_date": now,
            }
        ).eq("id", teacher_id).execute()
        return {
            "trusted": False,
            "verification_status": "unverified",
            "verification_score": 25.0,
            "message": (
                "We couldn't verify your certificate automatically. "
                "Please upload a clearer education certificate. "
                "If you believe this is an error, contact support."
            ),
            "reasons": ["Duplicate certificate detected"],
            "tavily": {"applied": False},
            "contact_support": True,
        }

    vision_bytes, vision_name = _downscale_for_vision(image_bytes, filename)
    vision = await _vision_soft_analyze(vision_bytes, vision_name, full_name)
    if vision.get("is_screenshot") is True:
        return {
            "trusted": False,
            "verification_status": "unverified",
            "verification_score": 15.0,
            "message": (
                "Screenshots are not allowed. "
                "Please upload a photo, scan, or PDF of your education certificate."
            ),
            "reasons": ["Screenshot detected"],
            "tavily": {"applied": False},
            "contact_support": False,
        }
    institution = vision.get("institution_name")
    if not isinstance(institution, str):
        institution = None
    try:
        tavily_meta = await asyncio.wait_for(
            _tavily_institution_soft(institution),
            timeout=6.0,
        )
    except asyncio.TimeoutError:
        logger.warning("Tavily soft check timed out — skipping")
        tavily_meta = {"applied": False, "delta": 0, "reason": "tavily_timeout"}
    score, reasons = _finalize_score(
        vision,
        full_name,
        float(tavily_meta.get("delta") or 0),
    )

    trusted = score >= TRUSTED_THRESHOLD
    status = "verified" if trusted else "unverified"
    now = datetime.now(timezone.utc).isoformat()
    cert_type = vision.get("certificate_type")
    if not isinstance(cert_type, str):
        cert_type = "other"
    cert_subject = vision.get("certificate_subject")
    if not isinstance(cert_subject, str):
        cert_subject = None

    cert_title = (title or "").strip() or cert_type.replace("_", " ").title()
    cert_status = "verified" if trusted else "pending"

    db.table("teacher_certificates").insert(
        {
            "teacher_id": teacher_id,
            "title": cert_title[:200],
            "status": cert_status,
            "certificate_type": cert_type[:80],
            "certificate_subject": (cert_subject or "")[:120] or None,
            "certificate_hash": digest,
            "verification_score": score,
            "verification_date": now,
        }
    ).execute()

    db.table("teacher_profiles").update(
        {
            "verification_status": status,
            "verification_score": score,
            "verification_date": now,
        }
    ).eq("id", teacher_id).execute()

    if trusted:
        message = "Trusted Teacher Badge awarded — soft AI verification passed (≥90%)."
    else:
        message = (
            "We couldn't verify your certificate automatically. "
            "Please upload a clearer education certificate. "
            "If you believe this is an error, contact support."
        )

    return {
        "trusted": trusted,
        "verification_status": status,
        "verification_score": score,
        "certificate_type": cert_type,
        "certificate_subject": cert_subject,
        "institution_name": institution,
        "message": message,
        "reasons": reasons,
        "tavily": tavily_meta,
        "contact_support": not trusted,
        "support_email": "support@examspark.app",
    }
