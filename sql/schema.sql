PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS experiments (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  hypothesis TEXT,
  north_star_metric_id INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('draft','running','paused','complete')),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (north_star_metric_id) REFERENCES metrics(id)
);

CREATE TABLE IF NOT EXISTS metrics (