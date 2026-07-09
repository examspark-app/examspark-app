from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from supabase import create_client, Client
import os

# Load environment variables
load_dotenv()

# Initialize FastAPI app
app = FastAPI(title="ExamSpark Backend", version="1.0.0")

# CORS middleware setup - allow all origins for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Supabase client
supabase_url: str = os.getenv("SUPABASE_URL")
supabase_key: str = os.getenv("SUPABASE_KEY")
supabase: Client = create_client(supabase_url, supabase_key)

# Health check endpoint
@app.get("/")
async def health_check():
    return {
        "status": "ExamSpark Backend Active",
        "database": "Connected"
    }

# Placeholder endpoint for AI question answering
@app.post("/api/v1/ask-ai")
async def ask_ai():
    """
    Placeholder endpoint for AI-powered question answering.
    Will handle:
    - Strict line-click redirect logic
    - AI credit checks and deductions
    - RAG-based responses using NCERT vectors and exam PYQs
    """
    return {
        "message": "AI endpoint placeholder - implementation pending",
        "status": "pending"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
