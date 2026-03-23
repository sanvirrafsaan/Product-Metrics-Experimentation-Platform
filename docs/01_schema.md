# init_db.py — SQL Logic Explained

This doc explains what each part of `init_db.py` does and **why** the SQL works this way.

---

## 1. Paths and setup

```python
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BASE_DIR, "data", "experiment.db")
SCHEMA_PATH = os.path.join(BASE_DIR, "sql", "schema.sql")
```

- `__file__` = path to `scripts/init_db.py`
- `dirname` twice = go up from `scripts/` to project root
- Ensures paths work whether you run from project root or `scripts/`

---

## 2. Fresh DB

```python
if os.path.exists(DB_PATH):
    os.remove(DB_PATH)
```

- Old DB may have different tables/columns
- Deleting avoids "table already exists" or schema conflicts
- Optional: you could instead run `DROP TABLE IF EXISTS ...` in reverse dependency order if you want to keep the file

---

## 3. Run schema.sql

```python
with open(SCHEMA_PATH, "r") as f:
    cursor.executescript(f.read())
```

- `executescript()` runs the whole file as one batch (multiple statements)
- Creates the 6 tables in order: metrics → experiments → guardrails → assignments → events → experiment_results
- Order matters: tables with foreign keys must be created **after** the tables they reference

---

## 4. Insert metrics

```sql
INSERT INTO metrics (name, description, metric_type)
VALUES ('checkout_conversion', 'Share of users who completed checkout', 'proportion')
```

- `metrics` has no foreign keys → insert first
- `metric_id` is `AUTOINCREMENT` → no need to pass it
- `event_type` in `events` will match these `name`s when you query

---

## 5. Insert experiments

```sql
INSERT INTO experiments (name, hypothesis, north_star_metric_id, status)
VALUES ('Simplified Checkout', 'Simpler checkout will boost conversion', 1, 'draft')
```

- `north_star_metric_id = 1` → points to `metrics.metric_id` for `checkout_conversion`
- Experiments reference metrics via FK, so metrics must exist first

---

## 6. Insert experiment_guardrails

```sql
INSERT INTO experiment_guardrails (experiment_id, metric_id, threshold, direction)
VALUES (1, 2, 0.05, 'upper_bound')
```

- Links an experiment to a metric with a rule
- `experiment_id=1, metric_id=2` → experiment 1, refund_rate
- `direction='upper_bound'` + `threshold=0.05` → refund_rate must be ≤ 5%
- `direction='lower_bound'` + `threshold=150` → aov must be ≥ 150
- `experiment_guardrails` is the M:N join between experiments and metrics

---

## 7. Insert assignments

```sql
INSERT INTO assignments (experiment_id, user_id, arm)
VALUES (1, 'user_exp1_0', 'control')
```

- One row per (experiment, user) → who got control vs treatment
- `arm` = `'control'` or `'treatment'`
- FK to `experiments`, so experiments must exist first

---

## 8. Insert events

```sql
INSERT INTO events (experiment_id, user_id, event_type, event_value)
VALUES (1, 'user_exp1_0', 'checkout_conversion', 1.0)
```

- One row per event
- `event_type` = metric name (e.g. `checkout_conversion`, `refund_rate`, `aov`)
- `event_value`:
  - For proportions: 0 or 1 (e.g. did not convert / converted)
  - For means: numeric (e.g. AOV dollars)
- Same user can have multiple rows for different `event_type`s
- Later queries filter by `event_type` to compute each metric

---

## 9. conn.commit() and conn.close()

- `commit()` writes all changes to disk
- Without it, changes stay in memory and are lost when the script exits
- `close()` releases the DB file and connection

---

## Insert order (dependency chain)

```
metrics          (no FKs)
    ↓
experiments      (FK: north_star_metric_id → metrics)
    ↓
experiment_guardrails  (FKs: experiment_id, metric_id)
assignments      (FK: experiment_id)
events           (FK: experiment_id)
```

`experiment_results` is never inserted here; the analysis engine fills it later.
