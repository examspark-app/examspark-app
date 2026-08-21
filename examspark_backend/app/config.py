"""Payment configuration — keys empty until production."""
import json
import os
from dotenv import load_dotenv

load_dotenv()


class PaymentConfig:
    # TODO: Razorpay Integration
    RAZORPAY_KEY_ID: str = os.getenv("RAZORPAY_KEY_ID", "")
    RAZORPAY_KEY_SECRET: str = os.getenv("RAZORPAY_KEY_SECRET", "")
    RAZORPAY_WEBHOOK_SECRET: str = os.getenv("RAZORPAY_WEBHOOK_SECRET", "")

    # TODO: PhonePe Integration
    PHONEPE_MERCHANT_ID: str = os.getenv("PHONEPE_MERCHANT_ID", "")
    PHONEPE_SALT_KEY: str = os.getenv("PHONEPE_SALT_KEY", "")
    PHONEPE_WEBHOOK_SECRET: str = os.getenv("PHONEPE_WEBHOOK_SECRET", "")

    # TODO: Google Play Billing — server-side verification
    GOOGLE_PLAY_PACKAGE_NAME: str = os.getenv("GOOGLE_PLAY_PACKAGE_NAME", "")
    GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: str = os.getenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "")

    IDEMPOTENCY_TTL_SECONDS: int = int(os.getenv("PAYMENT_IDEMPOTENCY_TTL", "86400"))

    @classmethod
    def is_testing(cls) -> bool:
        """Dev-only mock purchases. Never enable in production."""
        return os.getenv("IS_TESTING", "").strip().lower() in (
            "1",
            "true",
            "yes",
            "on",
        )

    @classmethod
    def razorpay_configured(cls) -> bool:
        return bool(cls.RAZORPAY_KEY_ID and cls.RAZORPAY_KEY_SECRET)

    @classmethod
    def phonepe_configured(cls) -> bool:
        return bool(cls.PHONEPE_MERCHANT_ID and cls.PHONEPE_SALT_KEY)

    @classmethod
    def google_play_configured(cls) -> bool:
        return bool(cls.GOOGLE_PLAY_PACKAGE_NAME and cls.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON)


class AIConfig:
    """AI pipeline config — model choices locked in TECH_STACK.md (Jul 12, 2026).

    Speech: Groq Whisper Turbo default, non-turbo fallback on low confidence.
    Text/Notes: Qwen3 32B via OpenRouter (Groq does not host Qwen3).
    """

    GROQ_API_KEY: str = os.getenv("GROQ_API_KEY", "")
    GROQ_WHISPER_TURBO_MODEL: str = os.getenv("GROQ_WHISPER_TURBO_MODEL", "whisper-large-v3-turbo")
    GROQ_WHISPER_STANDARD_MODEL: str = os.getenv("GROQ_WHISPER_STANDARD_MODEL", "whisper-large-v3")

    OPENROUTER_API_KEY: str = os.getenv("OPENROUTER_API_KEY", "")
    AI_CHAT_MODEL: str = os.getenv("AI_CHAT_MODEL", "qwen/qwen3")
    AI_FALLBACK_MODEL: str = os.getenv("AI_FALLBACK_MODEL", "qwen/qwen3")
    # Roleplay voice output reuses the same OpenRouter credential as Qwen3.
    # Keeping the model and voice configurable avoids embedding provider values
    # in the voice service.
    QWEN_TTS_MODEL: str = os.getenv(
        "QWEN_TTS_MODEL", "qwen/qwen-audio-3.0-tts-flash"
    )
    # Female American-English default for the English Roleplay teacher.
    QWEN_TTS_VOICE: str = os.getenv("QWEN_TTS_VOICE", "loongeva_v3.6")
    # RAG embeddings (Session 3) — must be 1536 dims to match schema.sql.
    AI_EMBEDDING_MODEL: str = os.getenv(
        "AI_EMBEDDING_MODEL", "openai/text-embedding-3-small"
    )
    # Vision (TECH_STACK.md): Flash default, Plus only on escalation.
    # Legacy AI_VISION_MODEL kept as Flash fallback if FLASH unset.
    AI_VISION_FLASH_MODEL: str = os.getenv(
        "AI_VISION_FLASH_MODEL",
        os.getenv("AI_VISION_MODEL", "qwen/qwen3-vl-8b-instruct"),
    )
    AI_VISION_PLUS_MODEL: str = os.getenv(
        "AI_VISION_PLUS_MODEL",
        "qwen/qwen3-vl-235b-a22b-instruct",
    )

    # Roleplay voice output only. Gemini TTS is separate from text generation.
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    GEMINI_TTS_MODEL: str = os.getenv(
        "GEMINI_TTS_MODEL", "gemini-2.5-flash-preview-tts"
    )
    GEMINI_TTS_VOICE: str = os.getenv("GEMINI_TTS_VOICE", "Kore")

    # Fish Audio uses account/library reference IDs rather than universal
    # male/female voice names. Configure both IDs in the deployment secret.
    FISH_AUDIO_API_KEY: str = os.getenv("FISH_AUDIO_API_KEY", "")
    FISH_AUDIO_TTS_MODEL: str = os.getenv(
        "FISH_AUDIO_TTS_MODEL", "fish-audio/s2.1-pro"
    )
    FISH_AUDIO_FEMALE_VOICE_ID: str = os.getenv(
        "FISH_AUDIO_FEMALE_VOICE_ID", ""
    )
    FISH_AUDIO_MALE_VOICE_ID: str = os.getenv(
        "FISH_AUDIO_MALE_VOICE_ID", ""
    )
    FISH_AUDIO_VOICE_IDS_JSON: str = os.getenv("FISH_AUDIO_VOICE_IDS_JSON", "")

    @classmethod
    def fish_audio_voice_ids(cls) -> dict[str, str]:
        try:
            value = json.loads(cls.FISH_AUDIO_VOICE_IDS_JSON or "{}")
            return value if isinstance(value, dict) else {}
        except json.JSONDecodeError:
            return {}

    # Whisper `verbose_json` confidence thresholds that trigger the
    # non-turbo re-transcription fallback (TECH_STACK.md Speech decision tree).
    LOW_CONFIDENCE_AVG_LOGPROB: float = -1.0
    HIGH_NO_SPEECH_PROB: float = 0.6

    @classmethod
    def groq_configured(cls) -> bool:
        return bool(cls.GROQ_API_KEY)

    @classmethod
    def openrouter_configured(cls) -> bool:
        return bool(cls.OPENROUTER_API_KEY)

    @classmethod
    def gemini_tts_configured(cls) -> bool:
        return bool(cls.GEMINI_API_KEY)

    @classmethod
    def fish_audio_configured(cls) -> bool:
        def usable(value: str) -> bool:
            cleaned = (value or "").strip()
            return bool(cleaned) and not (
                cleaned.startswith("<") and cleaned.endswith(">")
            )

        return bool(
            usable(cls.FISH_AUDIO_API_KEY)
            and usable(cls.FISH_AUDIO_FEMALE_VOICE_ID)
            and usable(cls.FISH_AUDIO_MALE_VOICE_ID)
        )

    @classmethod
    def tavily_configured(cls) -> bool:
        return bool((os.getenv("TAVILY_API_KEY") or "").strip())


class StorageConfig:
    """Cloudflare R2 (S3-compatible) — permanent transcript/notes storage.

    Postgres stores only the path string (TECH_STACK.md: metadata only).
    """

    CLOUDFLARE_ACCOUNT_ID: str = os.getenv("CLOUDFLARE_ACCOUNT_ID", "")
    R2_BUCKET_NAME: str = os.getenv("R2_BUCKET_NAME", "")
    R2_ACCESS_KEY_ID: str = os.getenv("R2_ACCESS_KEY_ID", "")
    R2_SECRET_ACCESS_KEY: str = os.getenv("R2_SECRET_ACCESS_KEY", "")
    R2_PUBLIC_URL: str = os.getenv("R2_PUBLIC_URL", "")

    @classmethod
    def endpoint_url(cls) -> str:
        return f"https://{cls.CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com"

    @classmethod
    def configured(cls) -> bool:
        return bool(
            cls.CLOUDFLARE_ACCOUNT_ID
            and cls.R2_BUCKET_NAME
            and cls.R2_ACCESS_KEY_ID
            and cls.R2_SECRET_ACCESS_KEY
        )
