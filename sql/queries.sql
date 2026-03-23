-- ============================================================
-- 4 CORE QUERIES for the analysis engine
-- Params: ? = experiment_id, ? = event_type (metric name)
-- Test in sqlite3: replace ? with values, e.g. 1 and 'checkout_conversion'
-- ============================================================

-- Query 1: Control arm stats (for North Star or any metric)
-- Params: (experiment_id, event_type) e.g. (1, 'checkout_conversion')
SELECT
  COUNT(DISTINCT a.user_id) AS control_n,
  AVG(e.event_value) AS control_mean
FROM (
  SELECT * FROM assignments
  WHERE experiment_id = ? AND arm = 'control'
) a
LEFT JOIN events e
  ON a.user_id = e.user_id
  AND a.experiment_id = e.experiment_id
  AND e.event_type = ?;


-- Query 2: Treatment arm stats (for North Star)
-- Params: (experiment_id, event_type)
SELECT
  COUNT(DISTINCT a.user_id) AS treatment_n,
  AVG(e.event_value) AS treatment_mean
FROM (
  SELECT * FROM assignments
  WHERE experiment_id = ? AND arm = 'treatment'
) a
LEFT JOIN events e
  ON a.user_id = e.user_id
  AND a.experiment_id = e.experiment_id
  AND e.event_type = ?;


-- Query 3: Treatment arm stats for a guardrail metric
-- Same as Query 2; use with each guardrail's metric name.
-- Params: (experiment_id, event_type) e.g. (1, 'refund_rate'), (1, 'aov')
SELECT
  COUNT(DISTINCT a.user_id) AS treatment_n,
  AVG(e.event_value) AS treatment_mean
FROM (
  SELECT * FROM assignments
  WHERE experiment_id = ? AND arm = 'treatment'
) a
LEFT JOIN events e
  ON a.user_id = e.user_id
  AND a.experiment_id = e.experiment_id
  AND e.event_type = ?;


-- Query 4: Get all guardrails for an experiment
-- Params: experiment_id
-- Returns: metric name (event_type), threshold, direction
SELECT
  m.name,
  m.metric_id,
  eg.threshold,
  eg.direction
FROM experiment_guardrails eg
JOIN metrics m ON eg.metric_id = m.metric_id
WHERE eg.experiment_id = ?;
