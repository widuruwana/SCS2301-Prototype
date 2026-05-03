# SCS2301 — Scholarship & Bursary Management System
## Project Plan — Prototype

> This is a **disposable prototype**. Its purpose is to validate the schema,
> discover hidden complexity, and establish the demo flow before the real build.
> No prototype code gets merged into the production repository.

---

## Problem Statement

Students seeking financial assistance have no transparent way to apply, track
their application status, or understand selection decisions. Scholarship
committees manage the entire process manually through paper, creating
inconsistency, delays, and no accountability on either side.

This system brings transparency and structure to both sides of that process.

---

## Tech Stack

| Concern       | Choice                          |
|---------------|---------------------------------|
| Language      | PHP 8.x                         |
| Database      | MySQL 8.x via PDO               |
| Frontend      | Raw HTML + CSS, no frameworks   |
| Libraries     | None — zero external dependencies |
| Local server  | XAMPP (Apache + MySQL)          |
| Dev env       | WSL2 Ubuntu on Windows 11       |
| Version control | Git + GitHub (private repo)   |

---

## User Roles

| Role      | Description                                               |
|-----------|-----------------------------------------------------------|
| student   | Self-registers, browses scholarships, submits applications |
| reviewer  | Assigned applications to score, submits reviews           |
| admin     | Creates scholarships, assigns reviewers, approves/rejects, manages disbursements |

---

## Scholarship Types

| Type       | Payment      | Review required | Notes                          |
|------------|--------------|-----------------|--------------------------------|
| one_time   | Single payment on approval | Yes (default) | e.g. Dean's Excellence Bursary |
| recurring  | Monthly installments for N months | Yes (default) | e.g. Mahapola |
| emergency  | Single payment, fast-tracked | No — admin approves directly | Shown with red visual indicator to students |

Emergency scholarships are regular one_time scholarships with `requires_review = 0`.
This single flag drives both the workflow (skip reviewer stage) and the UI (red border, emergency badge, sorted to top).

---

## Full Workflow

```
Admin creates scholarship
        ↓
Scholarship opens — students browse and apply
        ↓
Student submits application (statement + family income + supporting doc)
        ↓
        ├── requires_review = 1 → Admin assigns reviewers
        │           ↓
        │   Reviewers score independently (academic, need, overall — 1 to 10)
        │           ↓
        │   System aggregates scores, flags variance if reviewers differ by > 3
        │           ↓
        │   Admin views shortlist → approves or rejects with reason
        │
        └── requires_review = 0 → Admin approves directly
                    ↓
        Application approved → disbursement schedule generated
                    ↓
        one_time  → 1 row inserted, due immediately
        recurring → N rows inserted, one per month, dates increment
                    ↓
        Finance admin marks installments paid monthly
                    ↓
        Student sees payment schedule and history
```

---

## Application Withdrawal

- Students may withdraw a submitted application within **24 hours** of submission
- Applies to both regular and emergency scholarships
- Withdrawal sets status to `withdrawn`
- No withdrawal allowed once status moves to `under_review` or beyond

---

## Slot Enforcement

- Each scholarship has a fixed number of `slots`
- Slot availability is computed live via COUNT of approved applications — no counter column
- When approved count reaches slots, `scholarships.status` auto-sets to `closed` as part of the approval action
- Students cannot apply to a closed scholarship

---

## Student Profile Design

In the live system, student details (name, GPA, index number, faculty, etc.)
are pulled automatically from the faculty registry on login and are read-only.

In this prototype, students enter these details manually at registration
to simulate that behaviour. The profile page clearly notes this.

**Locked fields (faculty registry — student cannot edit):**
index number, full name, date of birth, address, faculty, department,
year of study, GPA

**Student-editable fields:**
bank account number, bank name, account holder name

Bank details are stored on the student profile, not on individual applications.
This ensures one source of truth across multiple scholarship awards.

---

## Disbursement Schedule Design

- One `disbursement_schedule` row per installment
- Bank details are **snapshotted** from `student_profiles` at the time of
  schedule generation — a later bank update does not retroactively alter
  already-scheduled installment records
- Overdue installments are computed at read time:
  `due_date < CURDATE() AND status = 'pending'` — no stored flag needed
- Finance admin marks installments paid individually from the disbursement dashboard
- The system does **not** move money — it is a record-keeping and coordination
  layer. Actual transfers happen through the university's existing financial system.

---

## Supporting Documents

- Students upload one supporting document per application (income proof, GN letter, etc.)
- Files are stored **outside webroot** at `C:/xampp/uploads/applications/`
- The database stores only the relative file path
- Files are served through `serve_file.php` which enforces authentication
  before streaming the file — direct URL access is not possible
- Reviewers and admins only can access uploaded documents

---

## Notifications

In-platform only. No email, no SMS — no external services required.

Notifications are inserted by PHP at these events:
- Application status changes (submitted → under_review → approved / rejected)
- Reviewer assigned to application
- Installment marked paid
- Application approved or rejected (with reason on rejection)

Students see an unread count badge in the nav. All notifications listed on a
dedicated page. Marked read on open.

---

## Database Schema — 9 Tables

| Table                  | Purpose                                              |
|------------------------|------------------------------------------------------|
| users                  | Auth credentials and role only                       |
| student_profiles       | Faculty data (locked) + bank details (editable)      |
| scholarships           | Scholarship listings created by admin                |
| eligibility_criteria   | Per-scholarship restrictions, all nullable           |
| applications           | One per student per scholarship, with status machine |
| reviewer_assignments   | Which reviewer is assigned to which application      |
| reviews                | Scores and notes per reviewer per application        |
| disbursement_schedule  | Installment rows generated on approval               |
| notifications          | In-platform notification inbox per user              |

---

## Application Status Machine

```
submitted → under_review → approved → [disbursement schedule generated]
                        → rejected  → [rejection reason shown to student]
submitted → withdrawn               → [only within 24 hours of submission]
```

---

## File Structure

```
SCS2301-Prototype/
│
├── config/
│   └── db.php                 ← PDO connection, dedicated DB user
│
├── core/
│   ├── session.php            ← session start, $_USER helper, login/logout
│   ├── auth.php               ← require_role(), 403 on violation
│   ├── helpers.php            ← sanitize, redirect, flash, format helpers
│   └── router.php             ← optional page routing
│
├── views/
│   ├── header.php             ← html head, nav, flash message render
│   └── footer.php             ← closing tags
│
├── auth/
│   ├── login.php              ← login form + POST handler
│   ├── logout.php             ← destroy session, redirect
│   └── register.php           ← student self-registration only
│
├── applicant/                 ← Module 1
│   ├── queries.php
│   ├── dashboard.php
│   ├── browse.php
│   ├── apply.php
│   ├── status.php
│   └── profile.php
│
├── scholarships/              ← Module 2
│   ├── queries.php
│   ├── index.php
│   ├── create.php
│   ├── edit.php
│   ├── view.php
│   └── toggle.php
│
├── review/                    ← Module 3 (recommended: own this module)
│   ├── queries.php            ← all scoring and workflow queries
│   ├── index.php              ← reviewer dashboard
│   ├── view.php               ← application detail + scoring form
│   ├── score.php              ← POST: save score
│   ├── shortlist.php          ← ranked output with variance flags
│   └── assign.php             ← POST: assign reviewer
│
├── disbursement/              ← Module 4
│   ├── queries.php
│   ├── index.php
│   ├── mark_paid.php
│   ├── renewals.php
│   └── reports.php
│
├── public/
│   └── style.css              ← single flat stylesheet
│
├── db/
│   └── schema.sql             ← full schema, version controlled
│
├── index.php                  ← entry point, redirects by role
└── PLAN.md                    ← this file
```

---

## Page Pattern — Every File Follows This

```php
<?php
require_once '../core/session.php';
require_once '../config/db.php';
require_once '../core/auth.php';
require_once '../core/helpers.php';
require_once 'queries.php';

require_role('reviewer');

// 1. handle POST first
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // validate → call query function → redirect
}

// 2. fetch data for render
$data = getSomeData($pdo, $_USER['id']);

// 3. render
require_once '../views/header.php';
// html here
require_once '../views/footer.php';
```

---

## Estimated Code Volume

| Scope              | Estimate          |
|--------------------|-------------------|
| Per module         | ~600–650 lines    |
| Shared core + auth | ~200 lines        |
| Full system        | ~2,600–2,800 lines |
| After optimization | ~2,200 lines (~15% reduction) |

---

## 12-Month Timeline

| Period      | Milestone                                              |
|-------------|--------------------------------------------------------|
| Month 1     | Proposal → panel approval · schema locked · repo setup |
| Month 2     | Basic CRUD per module, isolated, no integration yet    |
| Month 3     | Cross-module integration · full flow working           |
| Month 4     | Complete happy path demo · internal gate               |
| Month 5     | Polish · edge cases · UI consistency · access audit    |
| Month 6     | **Interim defense** — target 80%+ complete             |
| Months 7–9  | Optimization · reporting depth · documentation         |
| Month 10    | Code check dry runs · decision log written             |
| Month 11    | **Final defense** — 30 min presentation + full demo    |
| Month 12    | Buffer · individual code check                         |

---

## Grading Structure

```
Final defense score (out of 80)
    × code check percentage
        Task 1 — 60%
        Task 2 — 30%
        Code explanation — 10%
+ 15 marks from code checker
+  5 marks from supervisor
= 100 total
```

Code check only touches the files you personally authored.
Own your module completely — understand every line cold.

---

## Prototype Goals

Extract these three artifacts before archiving the prototype:

1. **Finalized schema** — corrected from what reality revealed was needed
2. **Module responsibility document** — what each person owns end to end
3. **Demo flow script** — exact sequence for the final defense narrative

---

## Prototype Rules

- Raw SQL strings are acceptable — skip prepared statements for speed
- Mixed logic and HTML is acceptable — this is throwaway code
- No prototype file gets committed to the production repository
- The value is what you learn, not what you write
