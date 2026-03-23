# The 4 Core Queries — Testing & Usage

## Quick test in sqlite3

From project root, with `data/experiment.db` initialized:

```bash
sqlite3 data/experiment.db
```

Then run (replace `1` with any experiment_id):

```sql
-- Query 1: Control stats for checkout_conversion
SELECT COUNT(DISTINCT a.user_id) AS control_n, AVG(e.event_value) AS control_mean
FROM (SELECT * FROM assignments WHERE experiment_id = 1 AND arm = 'control') a
LEFT JOIN events e ON a.user_id = e.user_id AND a.experiment_id = e.experiment_id AND e.event_type = 'checkout_conversion';

-- Query 2: Treatment stats for checkout_conversion
SELECT COUNT(DISTINCT a.user_id) AS treatment_n, AVG(e.event_value) AS treatment_mean
FROM (SELECT * FROM assignments WHERE experiment_id = 1 AND arm = 'treatment') a
LEFT JOIN events e ON a.user_id = e.user_id AND a.experiment_id = e.experiment_id AND e.event_type = 'checkout_conversion';

-- Query 3: Treatment stats for refund_rate (guardrail)
SELECT COUNT(DISTINCT a.user_id) AS treatment_n, AVG(e.event_value) AS treatment_mean
FROM (SELECT * FROM assignments WHERE experiment_id = 1 AND arm = 'treatment') a
LEFT JOIN events e ON a.user_id = e.user_id AND a.experiment_id = e.experiment_id AND e.event_type = 'refund_rate';

-- Query 4: List guardrails for experiment 1
SELECT m.name, m.metric_id, eg.threshold, eg.direction
FROM experiment_guardrails eg
JOIN metrics m ON eg.metric_id = m.metric_id
WHERE eg.experiment_id = 1;
```

## Python usage (for analysis engine later)

```python
# Query 1 & 2: (experiment_id, event_type)
control = cursor.execute(QUERY_1, (1, 'checkout_conversion')).fetchone()
treatment = cursor.execute(QUERY_2, (1, 'checkout_conversion')).fetchone()

# Query 4: (experiment_id,)
guardrails = cursor.execute(QUERY_4, (1,)).fetchall()

# For each guardrail, run Query 3: (experiment_id, metric_name)
for row in guardrails:
    name, metric_id, threshold, direction = row
    stats = cursor.execute(QUERY_3, (1, name)).fetchone()
```

## Expected results (with init_db test data)

- Query 1: `control_n` ≈ 50, `control_mean` ≈ 0.2–0.4 (proportion)
- Query 2: `treatment_n` ≈ 50, `treatment_mean` ≈ 0.2–0.4
- Query 4: refund_rate (upper_bound 0.05), aov (lower_bound 150)
