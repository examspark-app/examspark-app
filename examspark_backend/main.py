from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

from app.routers import payments, admin_payments, lectures, ask_ai, select_ai
from app.services.supabase_admin import get_supabase_admin

load_dotenv()

app = FastAPI(title="ExamSpark Backend", version="1.3.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(payments.router)
app.include_router(admin_payments.router)
app.include_router(lectures.router)
app.include_router(ask_ai.router)
app.include_router(select_ai.router)


@app.get("/")
async def health_check():
    db_status = "Connected"
    try:
        get_supabase_admin()
    except RuntimeError:
        db_status = "Not configured"
    return {
        "status": "ExamSpark Backend Active",
        "version": app.version,
        "database": db_status,
        "payments": "razorpay_web_and_play_code_ready",
        "lectures": "live_pipeline_audio_vision",
        "ask_ai": "rag_notes_transcript",
        "home_ai": "education_chat",
        "select_ai": "selection_scoped_stream",
        "ai_stream": "home_ai_stream_ask_ai_stream",
        "r2_layout": "users_library_v1",
    }


# Legacy webhook path — prefer /api/v1/payments/webhooks/razorpay
@app.post("/api/v1/payments/webhook")
async def payment_webhook_legacy():
    return {
        "status": "deprecated",
        "message": "Use POST /api/v1/payments/webhooks/razorpay",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
