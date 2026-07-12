-- ============================================================================
-- ExamSpark — Supabase Postgres Schema
-- Phase 4 (Architecture / Data Layer) — see PROJECT_ROADMAP.md
-- Nothing has been deployed yet — this whole file is meant to be run ONCE
-- in the Supabase SQL Editor on a fresh project.
-- ============================================================================

-- Enable pgvector extension for vector embeddings
CREATE EXTENSION IF NOT EXISTS vector;

-- ==================== USERS ====================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    full_name TEXT,
    photo_url TEXT,
    username TEXT UNIQUE,
    avatar_color TEXT,
    role TEXT NOT NULL DEFAULT 'teacher' CHECK (role IN ('teacher', 'student')),
    credits_balance INTEGER NOT NULL DEFAULT 100,
    -- Student onboarding screen (username/age/education/subjects) gate.
    -- Teachers are marked onboarded immediately — they set up their profile
    -- from the Teacher Dashboard instead (see teacher_profiles below).
    onboarding_completed BOOLEAN NOT NULL DEFAULT false,
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

-- PYQ reference metadata only (PROJECT_CORE_RULES.md §PYQ: never show
-- original question / options / answer key / explanation to students).
-- All PYQ content lives in Cloudflare R2. Postgres stores only the tags
-- and embedding used for RAG similarity lookup.
CREATE TABLE exam_pyqs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam TEXT NOT NULL CHECK (exam IN ('NEET', 'JEE', 'CBSE', 'UPSC')),
    year INTEGER NOT NULL,
    subject TEXT NOT NULL,
    chapter TEXT NOT NULL,
    weightage_stars INTEGER NOT NULL CHECK (weightage_stars >= 1 AND weightage_stars <= 5),
    r2_path TEXT,
    embedding vector(1536)
);

-- NCERT vector index for RAG. Chunk text lives in R2 (r2_chunk_path).
-- Postgres stores only metadata + embedding for similarity search.
CREATE TABLE ncert_vectors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject TEXT NOT NULL,
    chapter_name TEXT NOT NULL,
    page_number INTEGER NOT NULL,
    r2_chunk_path TEXT,
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
    -- How this lecture's content was captured. Only 'recorded' (real mic)
    -- lectures may be shared into a Group — prevents a teacher account from
    -- uploading arbitrary PDFs/audio and passing it off as live teaching.
    source_type TEXT NOT NULL DEFAULT 'recorded'
        CHECK (source_type IN ('recorded', 'uploaded_audio', 'uploaded_document')),
    -- R2 permanent storage pointer (DATA_STORAGE_POLICY.md) — Postgres holds the
    -- path only, e.g. "Users/{user_id}/Library/{lecture_id}/". Populated by
    -- Phase 5 FastAPI once R2 upload is wired.
    r2_folder_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Transcript metadata only. Full transcript text + clean transcript live in
-- Cloudflare R2. Postgres stores only R2 paths, ownership, and status.
CREATE TABLE transcripts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lecture_id UUID NOT NULL UNIQUE REFERENCES lectures(id) ON DELETE CASCADE,
    r2_transcript_path TEXT,
    clean_transcript_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Notes metadata only. All content (notes JSON, summary text, key points,
-- important terms) lives in Cloudflare R2. Postgres stores only R2 paths.
CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lecture_id UUID NOT NULL UNIQUE REFERENCES lectures(id) ON DELETE CASCADE,
    r2_notes_path TEXT,
    r2_summary_path TEXT,
    r2_key_points_path TEXT,
    r2_important_terms_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Extras metadata only. Flashcards, Quiz JSON, Revision, Formula, Mind Map,
-- Diagrams — all live in Cloudflare R2. Postgres stores type + path only.
CREATE TABLE extras (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lecture_id UUID NOT NULL REFERENCES lectures(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    r2_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (lecture_id, type)
);

CREATE TABLE credit_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,
    action TEXT,
    description TEXT NOT NULL,
    lecture_id UUID REFERENCES lectures(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==================== TEACHER PLATFORM TABLES ====================
-- See TEACHER_PLATFORM.md — public teacher profile shown on Teacher
-- Dashboard (edit mode) and Group Info screen (read-only, for students).

CREATE TABLE teacher_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    photo_url TEXT,
    subject TEXT NOT NULL,
    bio TEXT,
    qualification TEXT,
    experience_years INTEGER NOT NULL DEFAULT 0,
    verification_status TEXT NOT NULL DEFAULT 'unverified'
        CHECK (verification_status IN ('verified', 'pending', 'unverified')),
    is_suggested BOOLEAN NOT NULL DEFAULT false,
    -- Founder-locked Jul 2026: 30% recurring commission on any Group
    -- member's active paid-plan subscription, paid to that student's
    -- primary teacher (most recently joined Group). Display-only —
    -- see fn_teacher_estimated_commission(). CREDIT_ECONOMY.md §Teacher Commission.
    commission_rate NUMERIC NOT NULL DEFAULT 0.30,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Student profile — filled via the onboarding screen shown right after
-- signup (username/avatar_color live on users; age/education/subjects here).
-- Metadata only, mirrors the teacher_profiles pattern.
CREATE TABLE student_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    age INTEGER CHECK (age IS NULL OR (age >= 5 AND age <= 100)),
    education_level TEXT,
    subjects TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE teacher_certificates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES teacher_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    file_url TEXT,
    -- pending = awaiting review; verified/rejected set by the Phase 5 AI
    -- real/fake document check. Rejected shows "Contact Support" in the UI.
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'rejected')),
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE teacher_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES teacher_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    -- Matches TeacherAchievementType enum in teacher_achievement_model.dart
    type TEXT NOT NULL DEFAULT 'award' CHECK (type IN ('qualification', 'award', 'document')),
    image_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==================== GROUP SYSTEM TABLES ====================
-- Teacher-owned, broadcast-only "Groups" (WhatsApp FEEL, not chat) —
-- see PROJECT_CORE_RULES.md §2-4 and TEACHER_PLATFORM.md.
-- NOTE: backing tables are named class_folders/class_memberships to match
-- the terminology already locked in TEACHER_PLATFORM.md / FEATURES_MASTER.md
-- — this IS the "Groups" feature, not a separate system.

CREATE TABLE class_folders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    subject TEXT NOT NULL,
    description TEXT,
    join_code TEXT NOT NULL UNIQUE,
    is_public BOOLEAN NOT NULL DEFAULT true,
    allow_downloads BOOLEAN NOT NULL DEFAULT false,
    -- Access mode applied to members whose subscription has expired
    -- (TEACHER_PLATFORM.md §2 — "Read-only OR Locked, configurable")
    expired_access_mode TEXT NOT NULL DEFAULT 'read_only'
        CHECK (expired_access_mode IN ('read_only', 'locked')),
    -- FK added below (after group_shared_items exists) to avoid a circular
    -- CREATE TABLE dependency.
    pinned_item_id UUID,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE class_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id UUID NOT NULL REFERENCES class_folders(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (class_id, student_id)
);

-- The group feed — only the owning teacher may insert (PROJECT_CORE_RULES.md:
-- "Only Teacher can share content"). `shared_at` drives the join-before/after
-- access rule in fn_group_item_access() below.
CREATE TABLE group_shared_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id UUID NOT NULL REFERENCES class_folders(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES users(id),
    type TEXT NOT NULL CHECK (type IN ('lecture', 'homework', 'notes', 'quiz', 'announcement')),
    title TEXT NOT NULL,
    lecture_id UUID REFERENCES lectures(id) ON DELETE CASCADE,
    body TEXT,
    r2_path TEXT,
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    shared_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE class_folders
    ADD CONSTRAINT fk_class_folders_pinned_item
    FOREIGN KEY (pinned_item_id) REFERENCES group_shared_items(id) ON DELETE SET NULL;

-- ==================== RAG / VECTOR TABLES ====================
-- Mandatory RAG priority (PROJECT_CORE_RULES.md / TECH_STACK.md):
--   1. Notes  2. Clean Transcript  3. Teacher Shared  4. Web Search (Tavily)
-- Vectors only: Clean Transcript chunks + AI Notes + Teacher Shared Notes —
-- never raw audio / raw PDF / image binaries.

-- RAG vector index (pgvector = the vector database in this stack).
-- Chunk TEXT lives in R2 (r2_chunk_path). Postgres stores only metadata
-- + embedding for similarity search. chunk_hash enforces dedup
-- (PROJECT_CORE_RULES.md: "never duplicate vectors").
CREATE TABLE rag_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    lecture_id UUID REFERENCES lectures(id) ON DELETE CASCADE,
    source_type TEXT NOT NULL DEFAULT 'notes'
        CHECK (source_type IN ('notes', 'clean_transcript', 'teacher_shared')),
    teacher_id UUID REFERENCES users(id) ON DELETE SET NULL,
    group_id UUID REFERENCES class_folders(id) ON DELETE SET NULL,
    r2_chunk_path TEXT,
    chunk_hash TEXT,
    embedding vector(1536),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (lecture_id, source_type, chunk_hash)
);

-- ==================== INDEXES — LECTURE PIPELINE / TEACHER / GROUPS / RAG ====================

CREATE INDEX idx_lectures_user_id ON lectures(user_id);
CREATE INDEX idx_lectures_status ON lectures(status);
CREATE INDEX idx_notes_lecture_id ON notes(lecture_id);
CREATE INDEX idx_transcripts_lecture_id ON transcripts(lecture_id);
CREATE INDEX idx_extras_lecture_id ON extras(lecture_id);
CREATE INDEX idx_credit_transactions_user_id ON credit_transactions(user_id);

CREATE INDEX idx_student_profiles_user_id ON student_profiles(user_id);
CREATE INDEX idx_teacher_profiles_user_id ON teacher_profiles(user_id);
CREATE INDEX idx_teacher_profiles_is_suggested ON teacher_profiles(is_suggested);
CREATE INDEX idx_teacher_certificates_teacher_id ON teacher_certificates(teacher_id);
CREATE INDEX idx_teacher_achievements_teacher_id ON teacher_achievements(teacher_id);

CREATE INDEX idx_class_folders_teacher_id ON class_folders(teacher_id);
CREATE INDEX idx_class_folders_is_public ON class_folders(is_public);
CREATE INDEX idx_class_memberships_student_id ON class_memberships(student_id);
CREATE INDEX idx_class_memberships_class_id ON class_memberships(class_id);
CREATE INDEX idx_group_shared_items_class_id ON group_shared_items(class_id);
CREATE INDEX idx_group_shared_items_lecture_id ON group_shared_items(lecture_id);

CREATE INDEX idx_rag_documents_lecture_source ON rag_documents(lecture_id, source_type);
CREATE INDEX idx_rag_documents_group_id ON rag_documents(group_id);
CREATE INDEX idx_rag_documents_embedding ON rag_documents USING ivfflat (embedding vector_cosine_ops);

-- ==================== PAYMENT ARCHITECTURE TABLES ====================
-- Schema only — no live payment integration yet (Phase 5)

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
    -- How many Groups a student on this plan may join at once. -1 = unlimited.
    -- Founder-locked Jul 2026: free=0, plan_199=1, plan_499=3, plan_999=6, teacher=-1.
    max_groups INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO subscription_plans (id, name, tier, monthly_credits, price_inr_paise, platform, max_groups) VALUES
    ('free', 'Free', 'free', 50, 0, 'both', 0),
    ('plan_199', '₹199', 'entry', 1300, 19900, 'both', 1),
    ('plan_499', '₹499', 'mid', 3500, 49900, 'both', 3),
    ('plan_999', '₹999', 'premium', 8000, 99900, 'both', 6),
    ('teacher', 'Teacher', 'teacher', 20000, 199900, 'both', -1);

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

-- ============================================================================
-- FUNCTIONS — server-enforced credits, plan gating, group access rule
-- (CREDIT_ECONOMY.md: "Deduct credits server-side only")
-- ============================================================================

-- Guard so credits_balance can only change through fn_deduct_credits() below
-- (or a service-role client), never a direct client-side UPDATE.
CREATE OR REPLACE FUNCTION fn_protect_credits_balance()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.credits_balance IS DISTINCT FROM OLD.credits_balance
       AND current_setting('app.allow_credit_change', true) IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION 'credits_balance can only change via fn_deduct_credits()';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_protect_credits_balance
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION fn_protect_credits_balance();

-- Atomically checks balance, deducts, and logs the transaction.
-- Raises an exception (rolls back) if the balance is insufficient.
CREATE OR REPLACE FUNCTION fn_deduct_credits(
    p_user_id UUID,
    p_amount INTEGER,
    p_description TEXT,
    p_lecture_id UUID DEFAULT NULL,
    p_action TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_balance INTEGER;
BEGIN
    SELECT credits_balance INTO v_balance FROM users WHERE id = p_user_id FOR UPDATE;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'User % not found', p_user_id;
    END IF;

    IF v_balance < p_amount THEN
        RAISE EXCEPTION 'Insufficient credits: balance % < required %', v_balance, p_amount;
    END IF;

    PERFORM set_config('app.allow_credit_change', 'true', true);
    UPDATE users SET credits_balance = credits_balance - p_amount WHERE id = p_user_id;
    PERFORM set_config('app.allow_credit_change', 'false', true);

    INSERT INTO credit_transactions (user_id, amount, action, description, lecture_id)
    VALUES (p_user_id, -p_amount, p_action, p_description, p_lecture_id);

    RETURN v_balance - p_amount;
END;
$$;

-- Returns the caller's current active plan (defaults to 'free'). Used for
-- client-side gating today (plan_tier_gating.dart) and by FastAPI in Phase 5.
CREATE OR REPLACE FUNCTION fn_user_plan_tier(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_plan_id TEXT;
BEGIN
    SELECT plan_id INTO v_plan_id
    FROM user_subscriptions
    WHERE user_id = p_user_id
      AND status = 'active'
      AND current_period_end >= now()
    ORDER BY current_period_end DESC
    LIMIT 1;

    RETURN COALESCE(v_plan_id, 'free');
END;
$$;

-- Group access rule (TEACHER_PLATFORM.md §2):
--   * Joined BEFORE share  -> immediate access, subject to subscription state
--   * Joined AFTER share   -> access only if the item was shared during
--                             their active subscription period
--   * Expired subscription -> class_folders.expired_access_mode ('read_only'/'locked')
--   * Not a member         -> 'none'
CREATE OR REPLACE FUNCTION fn_group_item_access(p_user_id UUID, p_item_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_class_id UUID;
    v_shared_at TIMESTAMP;
    v_joined_at TIMESTAMP;
    v_expired_mode TEXT;
    v_sub_status TEXT;
    v_sub_start TIMESTAMP;
    v_sub_end TIMESTAMP;
BEGIN
    SELECT class_id, shared_at INTO v_class_id, v_shared_at
    FROM group_shared_items WHERE id = p_item_id;

    IF v_class_id IS NULL THEN
        RETURN 'none';
    END IF;

    SELECT joined_at INTO v_joined_at
    FROM class_memberships
    WHERE class_id = v_class_id AND student_id = p_user_id;

    IF v_joined_at IS NULL THEN
        RETURN 'none';
    END IF;

    SELECT expired_access_mode INTO v_expired_mode
    FROM class_folders WHERE id = v_class_id;

    SELECT status, current_period_start, current_period_end
    INTO v_sub_status, v_sub_start, v_sub_end
    FROM user_subscriptions
    WHERE user_id = p_user_id
    ORDER BY current_period_end DESC
    LIMIT 1;

    IF v_joined_at <= v_shared_at THEN
        IF v_sub_status IS NULL THEN
            -- No subscription row yet (e.g. still on Free tier) — default to
            -- full read access; feature-level credit/plan gating happens
            -- separately via fn_user_plan_tier() + plan_tier_gating.dart.
            RETURN 'full';
        ELSIF v_sub_status = 'active' AND v_sub_end >= now() THEN
            RETURN 'full';
        ELSE
            RETURN COALESCE(v_expired_mode, 'read_only');
        END IF;
    END IF;

    IF v_sub_start IS NOT NULL AND v_shared_at >= v_sub_start
       AND (v_sub_end IS NULL OR v_shared_at <= v_sub_end) THEN
        IF v_sub_status = 'active' THEN
            RETURN 'full';
        ELSE
            RETURN COALESCE(v_expired_mode, 'read_only');
        END IF;
    END IF;

    RETURN 'none';
END;
$$;

-- Estimated Teacher Commission (display-only — TEACHER_PLATFORM.md dashboard
-- card, CREDIT_ECONOMY.md §Teacher Commission). 30% recurring commission on
-- any Group member's active paid subscription, attributed to the student's
-- "primary teacher" = whoever owns the Group with the most recent
-- class_memberships.joined_at for that student (avoids double-paying when a
-- student belongs to multiple teachers' Groups). No real payout — Phase 5.
CREATE OR REPLACE FUNCTION fn_teacher_estimated_commission(p_teacher_id UUID)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rate NUMERIC;
    v_total NUMERIC;
BEGIN
    SELECT commission_rate INTO v_rate
    FROM teacher_profiles
    WHERE user_id = p_teacher_id;

    IF v_rate IS NULL THEN
        v_rate := 0.30;
    END IF;

    WITH primary_group AS (
        SELECT
            cm.student_id,
            cf.teacher_id,
            ROW_NUMBER() OVER (
                PARTITION BY cm.student_id
                ORDER BY cm.joined_at DESC
            ) AS rn
        FROM class_memberships cm
        JOIN class_folders cf ON cf.id = cm.class_id
    ),
    attributed_students AS (
        SELECT student_id
        FROM primary_group
        WHERE rn = 1 AND teacher_id = p_teacher_id
    ),
    active_paid_subs AS (
        SELECT us.user_id, sp.price_inr_paise
        FROM user_subscriptions us
        JOIN subscription_plans sp ON sp.id = us.plan_id
        WHERE us.status = 'active'
          AND us.current_period_end >= now()
          AND sp.price_inr_paise > 0
    )
    SELECT COALESCE(SUM(aps.price_inr_paise) / 100.0 * v_rate, 0)
    INTO v_total
    FROM attributed_students a
    JOIN active_paid_subs aps ON aps.user_id = a.student_id;

    RETURN ROUND(v_total, 2);
END;
$$;

GRANT EXECUTE ON FUNCTION fn_deduct_credits(UUID, INTEGER, TEXT, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_user_plan_tier(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_group_item_access(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION fn_teacher_estimated_commission(UUID) TO authenticated;

-- ============================================================================
-- ROW LEVEL SECURITY
-- PROJECT_CORE_RULES.md: "Students isolated; groups isolated; permission
-- check every AI request." Enforced here at the database layer.
-- ============================================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE lectures ENABLE ROW LEVEL SECURITY;
ALTER TABLE transcripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE extras ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rag_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_shared_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;

-- ---- users ----
CREATE POLICY "users_select_own" ON users FOR SELECT
    USING (auth.uid() = id);
CREATE POLICY "users_update_own" ON users FOR UPDATE
    USING (auth.uid() = id);

-- ---- lectures (owner + group members the lecture was shared with) ----
CREATE POLICY "lectures_select" ON lectures FOR SELECT
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM group_shared_items gsi
            WHERE gsi.lecture_id = lectures.id
              AND fn_group_item_access(auth.uid(), gsi.id) <> 'none'
        )
    );
CREATE POLICY "lectures_insert_own" ON lectures FOR INSERT
    WITH CHECK (user_id = auth.uid());
CREATE POLICY "lectures_update_own" ON lectures FOR UPDATE
    USING (user_id = auth.uid());
CREATE POLICY "lectures_delete_own" ON lectures FOR DELETE
    USING (user_id = auth.uid());

-- ---- transcripts (owner, written directly by LectureService.saveNotes) ----
CREATE POLICY "transcripts_select" ON transcripts FOR SELECT
    USING (
        EXISTS (SELECT 1 FROM lectures l WHERE l.id = transcripts.lecture_id AND l.user_id = auth.uid())
        OR EXISTS (
            SELECT 1 FROM group_shared_items gsi
            WHERE gsi.lecture_id = transcripts.lecture_id
              AND fn_group_item_access(auth.uid(), gsi.id) <> 'none'
        )
    );
CREATE POLICY "transcripts_write" ON transcripts FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM lectures l WHERE l.id = transcripts.lecture_id AND l.user_id = auth.uid()));
CREATE POLICY "transcripts_update" ON transcripts FOR UPDATE
    USING (EXISTS (SELECT 1 FROM lectures l WHERE l.id = transcripts.lecture_id AND l.user_id = auth.uid()));

-- ---- notes (owner, written directly by LectureService.saveNotes) ----
CREATE POLICY "notes_select" ON notes FOR SELECT
    USING (
        EXISTS (SELECT 1 FROM lectures l WHERE l.id = notes.lecture_id AND l.user_id = auth.uid())
        OR EXISTS (
            SELECT 1 FROM group_shared_items gsi
            WHERE gsi.lecture_id = notes.lecture_id
              AND fn_group_item_access(auth.uid(), gsi.id) <> 'none'
        )
    );
CREATE POLICY "notes_write" ON notes FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM lectures l WHERE l.id = notes.lecture_id AND l.user_id = auth.uid()));
CREATE POLICY "notes_update" ON notes FOR UPDATE
    USING (EXISTS (SELECT 1 FROM lectures l WHERE l.id = notes.lecture_id AND l.user_id = auth.uid()));

-- ---- extras (owner only) ----
CREATE POLICY "extras_select" ON extras FOR SELECT
    USING (EXISTS (SELECT 1 FROM lectures l WHERE l.id = extras.lecture_id AND l.user_id = auth.uid()));
CREATE POLICY "extras_write" ON extras FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM lectures l WHERE l.id = extras.lecture_id AND l.user_id = auth.uid()));
CREATE POLICY "extras_update" ON extras FOR UPDATE
    USING (EXISTS (SELECT 1 FROM lectures l WHERE l.id = extras.lecture_id AND l.user_id = auth.uid()));

-- ---- credit_transactions (read own history only; writes via fn_deduct_credits) ----
CREATE POLICY "credit_transactions_select_own" ON credit_transactions FOR SELECT
    USING (user_id = auth.uid());

-- ---- rag_documents (owner only; populated by service-role edge function) ----
CREATE POLICY "rag_documents_select_own" ON rag_documents FOR SELECT
    USING (user_id = auth.uid());

-- ---- class_folders (Groups) ----
CREATE POLICY "class_folders_select" ON class_folders FOR SELECT
    USING (
        is_public = true
        OR teacher_id = auth.uid()
        OR EXISTS (SELECT 1 FROM class_memberships cm WHERE cm.class_id = class_folders.id AND cm.student_id = auth.uid())
    );
CREATE POLICY "class_folders_insert_own" ON class_folders FOR INSERT
    WITH CHECK (teacher_id = auth.uid());
CREATE POLICY "class_folders_update_own" ON class_folders FOR UPDATE
    USING (teacher_id = auth.uid());
CREATE POLICY "class_folders_delete_own" ON class_folders FOR DELETE
    USING (teacher_id = auth.uid());

-- ---- class_memberships (join / leave) ----
CREATE POLICY "class_memberships_select" ON class_memberships FOR SELECT
    USING (
        student_id = auth.uid()
        OR EXISTS (SELECT 1 FROM class_folders cf WHERE cf.id = class_memberships.class_id AND cf.teacher_id = auth.uid())
    );
CREATE POLICY "class_memberships_join" ON class_memberships FOR INSERT
    WITH CHECK (student_id = auth.uid());
CREATE POLICY "class_memberships_leave" ON class_memberships FOR DELETE
    USING (student_id = auth.uid());

-- ---- group_shared_items (feed — teacher writes, members read per access fn) ----
CREATE POLICY "group_shared_items_select" ON group_shared_items FOR SELECT
    USING (
        teacher_id = auth.uid()
        OR fn_group_item_access(auth.uid(), id) <> 'none'
    );
CREATE POLICY "group_shared_items_insert" ON group_shared_items FOR INSERT
    WITH CHECK (
        teacher_id = auth.uid()
        AND EXISTS (SELECT 1 FROM class_folders cf WHERE cf.id = class_id AND cf.teacher_id = auth.uid())
    );
CREATE POLICY "group_shared_items_update" ON group_shared_items FOR UPDATE
    USING (teacher_id = auth.uid());
CREATE POLICY "group_shared_items_delete" ON group_shared_items FOR DELETE
    USING (teacher_id = auth.uid());

-- ---- student_profiles (owner only) ----
CREATE POLICY "student_profiles_select_own" ON student_profiles FOR SELECT
    USING (user_id = auth.uid());
CREATE POLICY "student_profiles_insert_own" ON student_profiles FOR INSERT
    WITH CHECK (user_id = auth.uid());
CREATE POLICY "student_profiles_update_own" ON student_profiles FOR UPDATE
    USING (user_id = auth.uid());

-- ---- teacher_profiles (public read, owner write) ----
CREATE POLICY "teacher_profiles_select_all" ON teacher_profiles FOR SELECT
    USING (true);
CREATE POLICY "teacher_profiles_insert_own" ON teacher_profiles FOR INSERT
    WITH CHECK (user_id = auth.uid());
CREATE POLICY "teacher_profiles_update_own" ON teacher_profiles FOR UPDATE
    USING (user_id = auth.uid());

-- ---- teacher_certificates (public read, owner write) ----
CREATE POLICY "teacher_certificates_select_all" ON teacher_certificates FOR SELECT
    USING (true);
CREATE POLICY "teacher_certificates_write_own" ON teacher_certificates FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM teacher_profiles tp WHERE tp.id = teacher_id AND tp.user_id = auth.uid()));
CREATE POLICY "teacher_certificates_delete_own" ON teacher_certificates FOR DELETE
    USING (EXISTS (SELECT 1 FROM teacher_profiles tp WHERE tp.id = teacher_id AND tp.user_id = auth.uid()));

-- ---- teacher_achievements (public read, owner write) ----
CREATE POLICY "teacher_achievements_select_all" ON teacher_achievements FOR SELECT
    USING (true);
CREATE POLICY "teacher_achievements_write_own" ON teacher_achievements FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM teacher_profiles tp WHERE tp.id = teacher_id AND tp.user_id = auth.uid()));
CREATE POLICY "teacher_achievements_delete_own" ON teacher_achievements FOR DELETE
    USING (EXISTS (SELECT 1 FROM teacher_profiles tp WHERE tp.id = teacher_id AND tp.user_id = auth.uid()));

-- ---- user_subscriptions (read own only; writes via payment webhooks / service role) ----
CREATE POLICY "user_subscriptions_select_own" ON user_subscriptions FOR SELECT
    USING (user_id = auth.uid());
