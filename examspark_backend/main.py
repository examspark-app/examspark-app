from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from app.api.v1 import webhooks_google_play, webhooks_razorpay, webhooks_phonepe, daily_quote

from app.routers import (
    payments,
    admin_payments,
    lectures,
    ask_ai,
    select_ai,
    coupons,
    notifications,
    groups,
    teachers,
    
)
from app.services.supabase_admin import get_supabase_admin

load_dotenv()

app = FastAPI(title="ExamSpark Backend", version="1.4.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://sonaxia.com",
        "https://www.sonaxia.com",
        "https://sonaxia.busbuddy25.workers.dev",
        "http://localhost:8080",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(payments.router)
app.include_router(admin_payments.router)
app.include_router(lectures.router)
app.include_router(ask_ai.router)
app.include_router(select_ai.router)
app.include_router(coupons.router)
app.include_router(notifications.router)
app.include_router(groups.router)
app.include_router(teachers.router)

app.include_router(webhooks_razorpay.router)
app.include_router(webhooks_google_play.router)
app.include_router(webhooks_phonepe.router)
app.include_router(daily_quote.router)


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
        "coupons": "teacher_first_month",
        "notifications": "in_app_and_fcm_ready",
        "teacher_share": "group_member_read_and_performance",
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
