PRAGMA foreign_keys = ON;

-- TABLE 1: metrics (must come first - experiments references it)
CREATE TABLE metrics (
  metric_id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  metric_type TEXT  -- 'proportion' or 'mean'
);

-- TABLE 2: experiments
CREATE TABLE experiments (
  experiment_id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  hypothesis TEXT,
  north_star_metric_id INTEGER,
  status TEXT DEFAULT 'draft',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (north_star_metric_id) REFERENCES metrics(metric_id)
);

-- TABLE 3: experiment_guardrails
CREATE TABLE experiment_guardrails (
  guardrail_id INTEGER PRIMARY KEY AUTOINCREMENT,
  experiment_id INTEGER,
  metric_id INTEGER,
  threshold REAL,
  direction TEXT,  -- 'lower_bound' or 'upper_bound'
  FOREIGN KEY (experiment_id) REFERENCES experiments(experiment_id),
  FOREIGN KEY (metric_id) REFERENCES metrics(metric_id)
);

-- TABLE 4: assignments
CREATE TABLE assignments (
  assignment_id INTEGER PRIMARY KEY AUTOINCREMENT,
  experiment_id INTEGER,
  user_id TEXT,
  arm TEXT,  -- 'control' or 'treatment'
  FOREIGN KEY (experiment_id) REFERENCES experiments(experiment_id)
);

-- TABLE 5: events
CREATE TABLE events (
  event_id INTEGER PRIMARY KEY AUTOINCREMENT,
  experiment_id INTEGER,
  user_id TEXT,
  event_type TEXT,
  event_value REAL,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (experiment_id) REFERENCES experiments(experiment_id)
);

-- TABLE 6: experiment_results
CREATE TABLE experiment_results (
  result_id INTEGER PRIMARY KEY AUTOINCREMENT,
  experiment_id INTEGER,
  metric_id INTEGER,
  control_n INTEGER,
  control_mean REAL,
  treatment_n INTEGER,
  treatment_mean REAL,
  uplift REAL,
  ci_lower REAL,
  ci_upper REAL,
  guardrail_passed INTEGER,  -- 1 or 0
  computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (experiment_id) REFERENCES experiments(experiment_id),
  FOREIGN KEY (metric_id) REFERENCES metrics(metric_id)
);
