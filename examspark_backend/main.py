from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from supabase import create_client, Client
import os

from app.routers import payments, admin_payments

load_dotenv()

app = FastAPI(title="ExamSpark Backend", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(payments.router)
app.include_router(admin_payments.router)

supabase_url: str = os.getenv("SUPABASE_URL")
supabase_key: str = os.getenv("SUPABASE_KEY")
supabase: Client = create_client(supabase_url, supabase_key)


@app.get("/")
async def health_check():
    return {
        "status": "ExamSpark Backend Active",
        "database": "Connected",
        "payments": "architecture_ready",
    }


@app.post("/api/v1/ask-ai")
async def ask_ai():
    return {
        "message": "AI endpoint placeholder - implementation pending",
        "status": "pending",
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