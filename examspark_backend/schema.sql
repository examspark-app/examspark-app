-- Enable pgvector extension for vector embeddings
CREATE EXTENSION IF NOT EXISTS vector;

-- Users table (extended with credits_balance for frontend)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL DEFAULT 'teacher' CHECK (role IN ('teacher', 'student')),
    credits_balance INTEGER NOT NULL DEFAULT 100,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Subscriptions table (legacy — prefer user_subscriptions for new payment flow)
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

-- ==================== LECTURE PIPELINE TABLES ====================

CREATE TABLE lectures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    subject TEXT,
    topic TEXT,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'splitting', 'transcribing', 'indexing', 'generating', 'almost_done', 'done', 'error')),
    high_accuracy BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE transcripts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lecture_id UUID NOT NULL UNIQUE REFERENCES lectures(id) ON DELETE CASCADE,
    content TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lecture_id UUID NOT NULL UNIQUE REFERENCES lectures(id) ON DELETE CASCADE,
    short_summary TEXT DEFAULT '',
    key_points JSONB DEFAULT '[]',
    clean_notes TEXT DEFAULT '',
    important_terms JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE extras (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lecture_id UUID NOT NULL REFERENCES lectures(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    content JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (lecture_id, type)
);

CREATE TABLE credit_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,
    description TEXT NOT NULL,
    lecture_id UUID REFERENCES lectures(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE class_folders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    subject TEXT NOT NULL,
    join_code TEXT NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE class_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id UUID NOT NULL REFERENCES class_folders(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (class_id, student_id)
);

CREATE TABLE rag_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    lecture_id UUID REFERENCES lectures(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    embedding vector(1536),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_lectures_user_id ON lectures(user_id);
CREATE INDEX idx_lectures_status ON lectures(status);
CREATE INDEX idx_notes_lecture_id ON notes(lecture_id);
CREATE INDEX idx_transcripts_lecture_id ON transcripts(lecture_id);
CREATE INDEX idx_extras_lecture_id ON extras(lecture_id);
CREATE INDEX idx_credit_transactions_user_id ON credit_transactions(user_id);
CREATE INDEX idx_class_folders_teacher_id ON class_folders(teacher_id);
CREATE INDEX idx_class_memberships_student_id ON class_memberships(student_id);

-- ==================== PAYMENT ARCHITECTURE TABLES ====================
-- Schema only — no live payment integration yet

-- Plan catalog (web + reference for Google Play product IDs)
CREATE TABLE subscription_plans (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    tier TEXT NOT NULL CHECK (tier IN ('free', 'entry', 'mid', 'premium', 'teacher')),
    monthly_credits INTEGER NOT NULL DEFAULT 0,
    price_inr_paise INTEGER NOT NULL DEFAULT 0,
    platform TEXT NOT NULL DEFAULT 'web' CHECK (platform IN ('web', 'android', 'both')),
    google_play_product_id TEXT,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO subscription_plans (id, name, tier, monthly_credits, price_inr_paise, platform) VALUES
    ('free', 'Free', 'free', 50, 0, 'both'),
    ('plan_199', '₹199', 'plan_199', 1300, 19900, 'both'),
    ('plan_499', '₹499', 'plan_499', 3500, 49900, 'both'),
    ('plan_999', '₹999', 'plan_999', 8000, 99900, 'both'),
    ('teacher', 'Teacher', 'teacher', 20000, 199900, 'both');

-- One-time credit packs (future)
CREATE TABLE credit_packs (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    credits INTEGER NOT NULL,
    price_inr_paise INTEGER NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true,
    google_play_product_id TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User subscriptions (enhanced)
CREATE TABLE user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan_id TEXT NOT NULL REFERENCES subscription_plans(id),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'active', 'expired', 'cancelled', 'grace_period')),
    platform TEXT NOT NULL CHECK (platform IN ('web', 'android')),
    gateway TEXT NOT NULL CHECK (gateway IN ('razorpay', 'phonepe', 'google_play')),
    current_period_start TIMESTAMP,
    current_period_end TIMESTAMP NOT NULL,
    google_play_purchase_token TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Teacher-specific subscription metadata
CREATE TABLE teacher_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_subscription_id UUID NOT NULL UNIQUE REFERENCES user_subscriptions(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    class_limit INTEGER DEFAULT 10,
    branding_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Payment orders / attempts
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id TEXT NOT NULL UNIQUE,
    plan_id TEXT REFERENCES subscription_plans(id),
    credit_pack_id TEXT REFERENCES credit_packs(id),
    gateway TEXT NOT NULL CHECK (gateway IN ('razorpay', 'phonepe', 'google_play')),
    platform TEXT NOT NULL CHECK (platform IN ('web', 'android')),
    amount_paise INTEGER NOT NULL,
    currency TEXT NOT NULL DEFAULT 'INR',
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'processing', 'verified', 'failed', 'refunded', 'cancelled')),
    gateway_order_id TEXT,
    gateway_payment_id TEXT,
    idempotency_key TEXT NOT NULL UNIQUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    verified_at TIMESTAMP
);

-- Financial transaction log (immutable)
CREATE TABLE payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('charge', 'refund', 'subscription_renewal', 'credit_pack')),
    amount_paise INTEGER NOT NULL,
    currency TEXT NOT NULL DEFAULT 'INR',
    status TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Credit allocation history (extends credit_transactions concept)
CREATE TABLE credit_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delta INTEGER NOT NULL,
    balance_after INTEGER NOT NULL,
    source TEXT NOT NULL CHECK (source IN (
        'subscription_monthly', 'credit_pack', 'manual_admin', 'refund', 'promo', 'usage'
    )),
    payment_id UUID REFERENCES payments(id) ON DELETE SET NULL,
    payment_transaction_id UUID REFERENCES payment_transactions(id) ON DELETE SET NULL,
    idempotency_key TEXT,
    description TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit log for payment operations
CREATE TABLE payment_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID REFERENCES payments(id) ON DELETE SET NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    level TEXT NOT NULL DEFAULT 'info' CHECK (level IN ('info', 'warn', 'error')),
    event TEXT NOT NULL,
    payload JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Webhook events (replay protection)
CREATE TABLE payment_webhooks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gateway TEXT NOT NULL CHECK (gateway IN ('razorpay', 'phonepe', 'google_play')),
    event_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload_hash TEXT NOT NULL,
    payload JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'received' CHECK (status IN ('received', 'processed', 'failed', 'duplicate')),
    processed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (gateway, event_id)
);

-- Idempotency keys (DB-backed; Redis preferred at scale)
CREATE TABLE payment_idempotency (
    key TEXT PRIMARY KEY,
    response JSONB NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_subscriptions_user_id ON user_subscriptions(user_id);
CREATE INDEX idx_user_subscriptions_status ON user_subscriptions(status);
CREATE INDEX idx_payments_user_id ON payments(user_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_order_id ON payments(order_id);
CREATE INDEX idx_payment_transactions_payment_id ON payment_transactions(payment_id);
CREATE INDEX idx_credit_history_user_id ON credit_history(user_id);
CREATE INDEX idx_payment_webhooks_gateway ON payment_webhooks(gateway);
CREATE INDEX idx_payment_logs_payment_id ON payment_logs(payment_id);

