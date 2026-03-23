---
name: Experimentation Platform Guide
overview: A self-guided roadmap to build the A/B test experimentation decision platform from scratch, with emphasis on understanding each component before coding.
todos:
  - id: phase1-schema
    content: Write full 6-table schema in sql/schema.sql (aligned with spec)
    status: pending
  - id: phase1-init
    content: Create init script + test data, verify in DB Browser
    status: pending
  - id: phase1-queries
    content: Write and test 4 core SQL queries in sql/queries.sql
    status: pending
  - id: phase2-flask
    content: Flask skeleton + get_db() helper + / route
    status: pending
  - id: phase2-routes
    content: /experiments/create and /experiments/<id> routes
    status: pending
  - id: phase3-upload
    content: "Upload route: parse CSV, insert into assignments + events"
    status: pending
  - id: phase3-analysis
    content: analyze_experiment() with CI + guardrail checks
    status: pending
  - id: phase3-analyze-results
    content: /analyze and /results routes
    status: pending
  - id: phase4-memo
    content: Memo generation + /memo/export route
    status: pending
  - id: phase4-polish
    content: UI polish, E2E testing, report
    status: pending
isProject: false
---

# Experimentation Platform — Self-Guided Build Guide

This guide walks you through the project **in the order you should build it**. You code; the guide tells you *what* to do, *why* it matters, and *what* to understand.

---

## Current State

- **Existing**: Partial `schema.sql` (incomplete, column names differ from spec), empty `queries.sql` and `test_data.sql`, empty docs, no Flask app
- **Recommendation**: Align with the spec's 6-table schema first. Your current schema uses `id` and `north_star_metric_id NOT NULL`; the spec uses `experiment_id` and allows nullable `north_star_metric_id` for draft experiments. Decide which convention to follow and stick to it.

---

## Phase 1: Database Foundation (Week 1, Days 1–3)

### 1.1 Schema DDL (Day 1 — ~2 hrs)

**Task**: Write the full 6-table schema in `[sql/schema.sql](sql/schema.sql)`.

**Tables in dependency order** (metrics first, since others reference it):

1. **metrics** — standalone lookup
2. **experiments** — references metrics (north_star)
3. **experiment_guardrails** — links experiments to metrics
4. **assignments** — experiment_id, user_id, arm
5. **events** — experiment_id, user_id, event_type, event_value
6. **experiment_results** — cached analysis output

**Things to understand**:

- Why `metrics` is separate: reusable across experiments
- Why `experiment_guardrails` is a join table: M:N between experiments and metrics
- `assignments` vs `events`: assignments = who got control/treatment; events = what happened (conversions, etc.)

**Viva prep**: "Normalized design. experiments = metadata, metrics = reusable, experiment_guardrails = M:N join, assignments = randomization, events = granular logs, experiment_results = cached stats."

---

### 1.2 Init DB and Test Data (Day 2 — ~2 hrs)

**Task**: Create `init_db.py` (or a shell script) that:

1. Runs `schema.sql`
2. Inserts 2–3 metrics (e.g. `checkout_conversion`, `refund_rate`, `aov`)
3. Inserts 2 experiments with guardrails
4. Inserts 100+ rows into `assignments` and `events` (control/treatment split)

**CSV shape** (matches what you'll upload later):


| user_id | experiment_id | arm       | event_type          | event_value |
| ------- | ------------- | --------- | ------------------- | ----------- |
| u1      | 1             | control   | checkout_conversion | 1           |
| u2      | 1             | treatment | checkout_conversion | 0           |


**Verify**: Open `experiment.db` in DB Browser for SQLite and inspect all 6 tables.

---

### 1.3 Write the 4 Core Queries (Day 3 — ~2 hrs)

**Task**: Add the 4 queries to `[sql/queries.sql](sql/queries.sql)` and test each in DB Browser.

**Query 1 — Control arm stats** (North Star metric):

```sql
SELECT 
  COUNT(DISTINCT a.user_id) as control_n,
  AVG(CASE WHEN e.event_value = 1 THEN 1.0 ELSE 0.0 END) as control_mean
FROM assignments a
LEFT JOIN events e ON a.user_id = e.user_id AND a.experiment_id = e.experiment_id
WHERE a.experiment_id = ? AND a.arm = 'control';
```

**Understand every line**:

- `LEFT JOIN` (not INNER): include users with no events (e.g. 0 conversions)
- `COUNT(DISTINCT a.user_id)`: unique users in control
- `CASE WHEN e.event_value = 1`: for binary metrics, 1 = success, 0 = no event
- `AVG(...)`: proportion of users with event_value=1

**Query 2**: Same pattern, `arm = 'treatment'`.

**Query 3**: Guardrail metric stats — same as Query 2 but filtered by `event_type` / `metric_id` (depends on how you store event_type in events).

**Query 4**: Get guardrails for an experiment:

```sql
SELECT m.name, eg.threshold, eg.direction
FROM experiment_guardrails eg
JOIN metrics m ON eg.metric_id = m.metric_id
WHERE eg.experiment_id = ?;
```

**Viva prep**: Practice explaining Query 1 line-by-line. Know why LEFT JOIN and why DISTINCT.

---

## Phase 2: Flask Skeleton (Week 1, Days 4–6)

### 2.1 Flask + DB Helper (Day 4 — ~2 hrs)

**Task**: Create `app.py` with:

1. Flask app init
2. `get_db()` helper (or context manager) that returns a sqlite3 connection
3. A simple `/` route that returns "Hello" to confirm it runs

**Understand**: How to open `sqlite3.connect('data/experiment.db')` and close it after each request (or use `g`).

---

### 2.2 Routes 1–3: List, Create, View (Days 5–6 — ~4 hrs)


| Route                 | Method   | What to build                                                                                           |
| --------------------- | -------- | ------------------------------------------------------------------------------------------------------- |
| `/`                   | GET      | Query all experiments, render list template                                                             |
| `/experiments/create` | GET/POST | Form: name, hypothesis, north_star (dropdown of metrics), 2 guardrails (metric + threshold + direction) |
| `/experiments/<id>`   | GET      | Fetch experiment + guardrails, show detail page with "Upload" and "Analyze" buttons                     |


**Create flow**: On POST, INSERT into `experiments` and `experiment_guardrails`. Redirect to `/experiments/<id>`.

**Checkpoint**: You can create experiments via the web form and see them in the DB.

---

## Phase 3: Upload + Analysis (Week 2)

### 3.1 Upload Route (Days 1–2 — ~5 hrs)

**Task**: `/experiments/<id>/upload` (POST) — accept CSV, parse, INSERT into `assignments` and `events`.

**Expected CSV columns** (define this clearly in your UI):

- `user_id`, `arm`, `event_type`, `event_value` (and optionally `timestamp`)

**Logic**:

1. Parse CSV (Python `csv` module or `pandas`)
2. For each row: INSERT into `assignments` (user_id, experiment_id, arm) — use `INSERT OR IGNORE` or check for duplicates
3. For each row: INSERT into `events` (experiment_id, user_id, event_type, event_value)

**Edge case**: Same user might have multiple events (e.g. multiple purchases). Assignments = 1 row per user per experiment; events = 1 row per event. Decide if your CSV has one row per user or multiple; adjust inserts accordingly.

---

### 3.2 Analysis Engine (Days 3–5 — ~8 hrs)

**Task**: Write `analyze_experiment(experiment_id)` in a separate module (e.g. `analysis.py`).

**Pseudocode**:

1. Get North Star metric_id from experiment
2. Query 1 & 2: control_n, control_mean, treatment_n, treatment_mean
3. Uplift = treatment_mean - control_mean
4. SE = sqrt( p_c*(1-p_c)/n_c + p_t*(1-p_t)/n_t )
5. CI = [uplift - 1.96*SE, uplift + 1.96*SE]
6. Query 4: get guardrails
7. For each guardrail: compute treatment-arm metric for that metric_id; check threshold (lower_bound: metric >= threshold? upper_bound: metric <= threshold?)
8. INSERT into `experiment_results`
9. Return dict with uplift, ci_lower, ci_upper, guardrails_passed

**Decision logic**:

- **Ship**: CI entirely above 0 AND all guardrails pass
- **Don't ship**: CI entirely below 0 OR any guardrail fails
- **Inconclusive**: CI includes 0

**Viva prep**: "Normal approximation for proportions. SE = sqrt(p1(1-p1)/n1 + p2(1-p2)/n2). Then uplift ± 1.96*SE." Know what "CI includes zero" means.

---

### 3.3 Analyze + Results Routes (Days 5–6)

**Task**:

- `/experiments/<id>/analyze` (POST): Call `analyze_experiment(id)`, redirect to `/experiments/<id>/results`
- `/experiments/<id>/results` (GET): Query `experiment_results` for this experiment, render table (metric, control mean, treatment mean, uplift, CI, pass/fail) + memo preview

**Checkpoint**: Full flow works — create → upload → analyze → view results.

---

## Phase 4: Memo + Polish (Week 3)

### 4.1 Memo Generation (Day 1 — ~2 hrs)

**Task**: Function `generate_memo(experiment_id)` that fills the template with:

- Experiment name, hypothesis
- North Star: control/treatment means, n, uplift, CI
- Guardrails: PASS/FAIL each
- Recommendation (ship / don't ship / inconclusive)
- Auto-filled rationale and next steps based on decision

Store memo text somewhere (e.g. in a `memos` table or in `experiment_results`, or regenerate on demand from `experiment_results`).

---

### 4.2 Export Route (Day 2 — ~1 hr)

**Task**: `/experiments/<id>/memo/export` (GET) — return memo as `.txt` download (`Content-Disposition: attachment`).

---

### 4.3 UI Polish + Report (Days 2–4)

- Bootstrap tables, flash messages for errors
- End-to-end test with a realistic CSV
- Write report (use the outline in your spec)

---

## Spec Clarifications to Resolve

1. **event_type vs metric_id**: Your `events` table has `event_type` (TEXT). Your `metrics` table has `metric_id` (INT). You need a clear mapping: either event_type = metric name, or add metric_id to events. The queries assume you can join events to metrics — decide how.
2. **Guardrail direction**: `lower_bound` = "metric must be >= threshold" (e.g. AOV >= 150)? Or "metric must be <= threshold" for bad things (refund_rate <= 0.05)? The spec says direction is `lower_bound` or `upper_bound` — define explicitly for each.
3. **Assignments vs Events**: One assignment per user per experiment. Events can be multiple per user (e.g. page views). For binary conversion, typically one event per user (1 or 0). Your CSV format will dictate this — document it.
4. **experiment_id in events**: Both `assignments` and `events` have `experiment_id`. The JOIN in Query 1 uses `a.experiment_id = e.experiment_id` — so events must be scoped to the experiment. Your upload logic must set `experiment_id` on every event insert.

---

## Recommended File Structure

```
Product-Metrics-Experimentation-Platform/
├── app.py                 # Flask app, routes
├── analysis.py            # analyze_experiment(), generate_memo()
├── requirements.txt       # flask
├── data/
│   └── experiment.db      # SQLite (or app.db — pick one)
├── sql/
│   ├── schema.sql
│   ├── queries.sql
│   └── test_data.sql
├── templates/
│   ├── index.html
│   ├── experiment_create.html
│   ├── experiment_detail.html
│   ├── results.html
│   └── ...
└── static/                # Optional: custom CSS
```

---

## Learning Checklist (Mastery for Viva)

- Explain 6-table schema and why each table exists
- Walk through Query 1 line-by-line (LEFT JOIN, COUNT DISTINCT, CASE WHEN)
- Write SE and CI formula from memory
- Explain: "What if CI includes zero?" → Inconclusive, don't ship
- Name 3 things you'd add next (SRM, segments, power calculator)

---

## When You're Stuck

- **Schema/SQL**: Test each query in DB Browser with `?` replaced by a real experiment_id
- **CI formula**: Double-check: SE is for the *difference* (treatment - control), not for each arm separately
- **Flask**: Use `request.files['csv']` for upload; `send_file()` or `Response(memo, mimetype='text/plain')` for export

