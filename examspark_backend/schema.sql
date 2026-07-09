-- Enable pgvector extension for vector embeddings
CREATE EXTENSION IF NOT EXISTS vector;

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('teacher', 'student')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Subscriptions table
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_type TEXT NOT NULL,
    active_month TEXT NOT NULL,
    status TEXT NOT NULL,
    expires_at TIMESTAMP NOT NULL
);

-- AI Credits Ledger table
CREATE TABLE ai_credits_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    total_credits_allocated NUMERIC NOT NULL DEFAULT 0,
    credits_used NUMERIC NOT NULL DEFAULT 0,
    remaining_credits NUMERIC NOT NULL DEFAULT 0,
    last_topup_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Exam PYQs (Previous Year Questions) table
CREATE TABLE exam_pyqs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam TEXT NOT NULL CHECK (exam IN ('NEET', 'JEE', 'CBSE', 'UPSC')),
    year INTEGER NOT NULL,
    subject TEXT NOT NULL,
    chapter TEXT NOT NULL,
    question_text TEXT NOT NULL,
    options JSONB NOT NULL,
    correct_option TEXT NOT NULL,
    detailed_solution TEXT,
    weightage_stars INTEGER NOT NULL CHECK (weightage_stars >= 1 AND weightage_stars <= 5),
    embedding vector(1536)
);

-- NCERT Vectors table for RAG
CREATE TABLE ncert_vectors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject TEXT NOT NULL,
    chapter_name TEXT NOT NULL,
    page_number INTEGER NOT NULL,
    content_chunk TEXT NOT NULL,
    embedding vector(1536)
);

-- Create indexes for better query performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_active_month ON subscriptions(active_month);
CREATE INDEX idx_ai_credits_user_id ON ai_credits_ledger(user_id);
CREATE INDEX idx_exam_pyqs_exam_year ON exam_pyqs(exam, year);
CREATE INDEX idx_exam_pyqs_subject_chapter ON exam_pyqs(subject, chapter);
CREATE INDEX idx_ncert_vectors_subject ON ncert_vectors(subject);
CREATE INDEX idx_ncert_vectors_chapter ON ncert_vectors(chapter_name);

-- Create vector similarity indexes for RAG queries
CREATE INDEX idx_exam_pyqs_embedding ON exam_pyqs USING ivfflat (embedding vector_cosine_ops);
CREATE INDEX idx_ncert_vectors_embedding ON ncert_vectors USING ivfflat (embedding vector_cosine_ops);
