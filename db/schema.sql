-- ============================================================
-- SCS2301 Scholarship & Bursary Management System
-- Final Prototype Schema
-- ============================================================

CREATE DATABASE IF NOT EXISTS scs2301_prototype
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE scs2301_prototype;

-- ============================================================
-- 1. USERS
-- Auth credentials and role only.
-- All profile data lives in student_profiles.
-- Roles: student, reviewer, admin
-- ============================================================
CREATE TABLE users (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email           VARCHAR(150)    NOT NULL UNIQUE,
    password_hash   VARCHAR(255)    NOT NULL,
    role            ENUM('student','reviewer','admin') NOT NULL DEFAULT 'student',
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 2. STUDENT PROFILES
-- Populated at registration, simulating a faculty database pull.
-- Fields from index_number to gpa are locked — student cannot edit.
-- Bank details are the only student-editable fields.
-- ============================================================
CREATE TABLE student_profiles (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id             INT UNSIGNED        NOT NULL UNIQUE,

    -- locked fields (sourced from faculty database)
    index_number        VARCHAR(20)         NOT NULL UNIQUE,
    full_name           VARCHAR(150)        NOT NULL,
    date_of_birth       DATE                NULL,
    address             TEXT                NULL,
    faculty             VARCHAR(100)        NULL,
    department          VARCHAR(100)        NULL,
    year_of_study       TINYINT UNSIGNED    NULL,
    gpa                 DECIMAL(3,2)        NULL,

    -- editable by student
    bank_account_no     VARCHAR(50)         NULL,
    bank_name           VARCHAR(100)        NULL,
    account_holder_name VARCHAR(150)        NULL,

    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- ============================================================
-- 3. SCHOLARSHIPS
-- Created and managed by admin.
-- payment_type drives disbursement schedule generation.
-- requires_review = 0 means emergency — skips reviewer stage,
--   triggers visual emergency indicators in UI.
-- duration_months is only used when payment_type = 'recurring'.
-- slots = max number of approved applications allowed.
--   when approved count reaches slots, status auto-closes.
-- ============================================================
CREATE TABLE scholarships (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title               VARCHAR(200)        NOT NULL,
    description         TEXT                NOT NULL,
    amount              DECIMAL(10,2)       NOT NULL,
    payment_type        ENUM('one_time','recurring') NOT NULL DEFAULT 'one_time',
    duration_months     TINYINT UNSIGNED    NULL,
    slots               INT UNSIGNED        NOT NULL DEFAULT 1,
    deadline            DATE                NULL,
    requires_review     TINYINT(1)          NOT NULL DEFAULT 1,
    status              ENUM('open','closed') NOT NULL DEFAULT 'open',
    created_by          INT UNSIGNED        NOT NULL,
    created_at          TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (created_by) REFERENCES users(id)
);

-- ============================================================
-- 4. ELIGIBILITY CRITERIA
-- One row per scholarship. All restriction fields are nullable —
-- a null value means no restriction on that criterion.
-- Checked at application time and flagged if not met,
-- but not hard-blocked — reviewer makes final call.
-- ============================================================
CREATE TABLE eligibility_criteria (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    scholarship_id      INT UNSIGNED        NOT NULL UNIQUE,
    min_gpa             DECIMAL(3,2)        NULL,
    max_family_income   DECIMAL(12,2)       NULL,
    year_of_study       TINYINT UNSIGNED    NULL,
    notes               TEXT                NULL,

    FOREIGN KEY (scholarship_id) REFERENCES scholarships(id)
);

-- ============================================================
-- 5. APPLICATIONS
-- One application per student per scholarship (unique key).
-- gpa and year_of_study are not stored here — pulled from
--   student_profiles at review time, cannot be falsified.
-- family_income is self-reported with supporting document.
-- supporting_doc stores relative path to file outside webroot.
-- withdrawn status only allowed within 24 hours of submission.
-- approved_by and approved_at form the approval audit trail.
-- rejection_reason is shown to the student on their status page.
-- ============================================================
CREATE TABLE applications (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id             INT UNSIGNED        NOT NULL,
    scholarship_id      INT UNSIGNED        NOT NULL,
    statement           TEXT                NOT NULL,
    family_income       DECIMAL(12,2)       NULL,
    supporting_doc      VARCHAR(500)        NULL,
    status              ENUM(
                            'submitted',
                            'under_review',
                            'approved',
                            'rejected',
                            'withdrawn'
                        ) NOT NULL DEFAULT 'submitted',
    rejection_reason    TEXT                NULL,
    approved_by         INT UNSIGNED        NULL,
    approved_at         TIMESTAMP           NULL,
    submitted_at        TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY unique_application (user_id, scholarship_id),
    FOREIGN KEY (user_id)        REFERENCES users(id),
    FOREIGN KEY (scholarship_id) REFERENCES scholarships(id),
    FOREIGN KEY (approved_by)    REFERENCES users(id)
);

-- ============================================================
-- 6. REVIEWER ASSIGNMENTS
-- Admin assigns one or more reviewers to an application.
-- A reviewer can only be assigned once per application.
-- Emergency scholarships (requires_review = 0) skip this stage.
-- ============================================================
CREATE TABLE reviewer_assignments (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    application_id      INT UNSIGNED        NOT NULL,
    reviewer_id         INT UNSIGNED        NOT NULL,
    assigned_at         TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY unique_assignment (application_id, reviewer_id),
    FOREIGN KEY (application_id) REFERENCES applications(id),
    FOREIGN KEY (reviewer_id)    REFERENCES users(id)
);

-- ============================================================
-- 7. REVIEWS
-- One review per reviewer per application.
-- Scores are 1-10. Aggregation and variance detection in PHP.
-- Variance flag: if two reviewers differ by more than 3 points
--   on overall_score, admin is prompted to seek a third review.
-- Emergency scholarships (requires_review = 0) have no reviews.
-- ============================================================
CREATE TABLE reviews (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    application_id      INT UNSIGNED        NOT NULL,
    reviewer_id         INT UNSIGNED        NOT NULL,
    academic_score      TINYINT UNSIGNED    NOT NULL CHECK (academic_score BETWEEN 1 AND 10),
    need_score          TINYINT UNSIGNED    NOT NULL CHECK (need_score BETWEEN 1 AND 10),
    overall_score       TINYINT UNSIGNED    NOT NULL CHECK (overall_score BETWEEN 1 AND 10),
    notes               TEXT                NULL,
    reviewed_at         TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY unique_review (application_id, reviewer_id),
    FOREIGN KEY (application_id) REFERENCES applications(id),
    FOREIGN KEY (reviewer_id)    REFERENCES users(id)
);

-- ============================================================
-- 8. DISBURSEMENT SCHEDULE
-- Generated automatically when an application is approved.
-- one_time     → 1 row,  installment_no = 1
-- recurring    → N rows, one per month, installment_no = 1..N
-- due_date increments by 1 month per installment for recurring.
-- overdue is computed at read time:
--   due_date < CURDATE() AND status = 'pending'
-- marked_paid_by records which admin processed the payment.
-- bank details are snapshotted from student_profiles at the
--   time of schedule generation so a later bank change does
--   not silently affect already-scheduled installments.
-- ============================================================
CREATE TABLE disbursement_schedule (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    application_id      INT UNSIGNED        NOT NULL,
    installment_no      TINYINT UNSIGNED    NOT NULL,
    amount              DECIMAL(10,2)       NOT NULL,
    due_date            DATE                NOT NULL,
    status              ENUM('pending','paid') NOT NULL DEFAULT 'pending',
    paid_at             TIMESTAMP           NULL,
    marked_paid_by      INT UNSIGNED        NULL,

    -- bank details snapshotted at schedule generation time
    bank_account_no     VARCHAR(50)         NULL,
    bank_name           VARCHAR(100)        NULL,
    account_holder_name VARCHAR(150)        NULL,

    UNIQUE KEY unique_installment (application_id, installment_no),
    FOREIGN KEY (application_id)  REFERENCES applications(id),
    FOREIGN KEY (marked_paid_by)  REFERENCES users(id)
);

-- ============================================================
-- 9. NOTIFICATIONS
-- Inserted by PHP at key workflow events:
--   - application status changes
--   - reviewer assigned
--   - installment marked paid
--   - application approved or rejected
-- is_read toggled when student opens notification panel.
-- ============================================================
CREATE TABLE notifications (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id     INT UNSIGNED        NOT NULL,
    message     TEXT                NOT NULL,
    is_read     TINYINT(1)          NOT NULL DEFAULT 0,
    created_at  TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- ============================================================
-- SEED DATA
-- One account per role for immediate prototype testing.
-- All passwords are: Password1!
-- The student seed has a complete profile including bank details
--   so the application flow can be tested end to end immediately.
-- ============================================================

INSERT INTO users (email, password_hash, role) VALUES
(
    'admin@scs.lk',
    '$2y$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
    'admin'
),
(
    'reviewer@scs.lk',
    '$2y$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
    'reviewer'
),
(
    'student@scs.lk',
    '$2y$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi',
    'student'
);

INSERT INTO student_profiles (
    user_id,
    index_number,
    full_name,
    date_of_birth,
    address,
    faculty,
    department,
    year_of_study,
    gpa,
    bank_account_no,
    bank_name,
    account_holder_name
) VALUES (
    3,
    'CS/2022/001',
    'Widuru Wana',
    '2003-05-15',
    '42 Galle Road, Negombo, Western Province',
    'Faculty of Computing',
    'Computer Science',
    2,
    3.57,
    '1234567890',
    'Bank of Ceylon',
    'Widuru Wana'
);

-- seed one open regular scholarship
INSERT INTO scholarships (
    title, description, amount, payment_type,
    duration_months, slots, deadline,
    requires_review, status, created_by
) VALUES (
    'Mahapola Merit Scholarship',
    'Monthly merit-based scholarship for undergraduate students demonstrating academic excellence and financial need.',
    3500.00,
    'recurring',
    12,
    10,
    DATE_ADD(CURDATE(), INTERVAL 30 DAY),
    1,
    'open',
    1
);

INSERT INTO eligibility_criteria (
    scholarship_id, min_gpa, max_family_income, year_of_study, notes
) VALUES (
    1, 3.00, 50000.00, NULL,
    'Open to all years. GPA minimum 3.00. Family income below Rs. 50,000 per month.'
);

-- seed one open one-time scholarship
INSERT INTO scholarships (
    title, description, amount, payment_type,
    duration_months, slots, deadline,
    requires_review, status, created_by
) VALUES (
    'Dean\'s Excellence Bursary',
    'One-time award for students demonstrating outstanding academic performance in their first year.',
    25000.00,
    'one_time',
    NULL,
    5,
    DATE_ADD(CURDATE(), INTERVAL 14 DAY),
    1,
    'open',
    1
);

INSERT INTO eligibility_criteria (
    scholarship_id, min_gpa, max_family_income, year_of_study, notes
) VALUES (
    2, 3.50, NULL, 2,
    'Second year students only. GPA minimum 3.50. No income restriction.'
);

-- seed one emergency scholarship
INSERT INTO scholarships (
    title, description, amount, payment_type,
    duration_months, slots, deadline,
    requires_review, status, created_by
) VALUES (
    'Emergency Financial Assistance Fund',
    'Immediate financial assistance for students facing unexpected hardship. No review stage — admin approved.',
    15000.00,
    'one_time',
    NULL,
    20,
    DATE_ADD(CURDATE(), INTERVAL 7 DAY),
    0,
    'open',
    1
);

INSERT INTO eligibility_criteria (
    scholarship_id, min_gpa, max_family_income, year_of_study, notes
) VALUES (
    3, NULL, NULL, NULL,
    'No eligibility restrictions. All students eligible. Supporting documentation required.'
);