"""
Initialize the SQLite database: drop old tables, run schema, insert test data.
Run from project root: python scripts/init_db.py
"""
import os
import random
import sqlite3

# Paths relative to project root (where you run the script from)
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BASE_DIR, "data", "experiment.db")
SCHEMA_PATH = os.path.join(BASE_DIR, "sql", "schema.sql")


def init_db():
    # Remove existing DB so we start fresh (avoids "table already exists" from old schema)
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # --- 1. Run schema.sql (creates all 6 tables) ---
    with open(SCHEMA_PATH, "r") as f:
        cursor.executescript(f.read())

    # --- 2. Insert metrics (no foreign keys, insert first) ---
    cursor.executemany(
        """
        INSERT INTO metrics (name, description, metric_type)
        VALUES (?, ?, ?)
        """,
        [
            ("checkout_conversion", "Share of users who completed checkout", "proportion"),
            ("refund_rate", "Share of users who requested a refund", "proportion"),
            ("aov", "Average order value in dollars", "mean"),
        ],
    )

    # --- 3. Insert experiments (references metrics via north_star_metric_id) ---
    cursor.executemany(
        """
        INSERT INTO experiments (name, hypothesis, north_star_metric_id, status)
        VALUES (?, ?, ?, ?)
        """,
        [
            ("Simplified Checkout", "Simpler checkout will boost conversion", 1, "draft"),
            ("New Onboarding Flow", "New flow improves activation", 1, "draft"),
        ],
    )

    # --- 4. Insert experiment_guardrails (links experiments to metrics with thresholds) ---
    cursor.executemany(
        """
        INSERT INTO experiment_guardrails (experiment_id, metric_id, threshold, direction)
        VALUES (?, ?, ?, ?)
        """,
        [
            (1, 2, 0.05, "upper_bound"),   # exp 1: refund_rate must be <= 5%
            (1, 3, 150.0, "lower_bound"),  # exp 1: aov must be >= $150
            (2, 2, 0.05, "upper_bound"),   # exp 2: same guardrails
            (2, 3, 120.0, "lower_bound"),
        ],
    )

    # --- 5. Insert assignments (who got control vs treatment) ---
    random.seed(42)
    for exp_id in [1, 2]:
        for i in range(100):
            user_id = f"user_exp{exp_id}_{i}"
            arm = "treatment" if random.random() < 0.5 else "control"
            cursor.execute(
                "INSERT INTO assignments (experiment_id, user_id, arm) VALUES (?, ?, ?)",
                (exp_id, user_id, arm),
            )

    # --- 6. Insert events (what happened: conversions, refunds, order values) ---
    random.seed(42)
    for exp_id in [1, 2]:
        for i in range(100):
            user_id = f"user_exp{exp_id}_{i}"
            # checkout_conversion: 1 = converted, 0 = didn't (binary)
            converted = 1 if random.random() < 0.25 else 0
            cursor.execute(
                """INSERT INTO events (experiment_id, user_id, event_type, event_value)
                   VALUES (?, ?, ?, ?)""",
                (exp_id, user_id, "checkout_conversion", float(converted)),
            )
            # refund_rate: 1 = refunded, 0 = didn't
            refunded = 1 if random.random() < 0.03 else 0
            cursor.execute(
                """INSERT INTO events (experiment_id, user_id, event_type, event_value)
                   VALUES (?, ?, ?, ?)""",
                (exp_id, user_id, "refund_rate", float(refunded)),
            )
            # aov: dollar amount (0 if no purchase, else 100–300)
            aov = random.uniform(100, 300) if converted else 0.0
            cursor.execute(
                """INSERT INTO events (experiment_id, user_id, event_type, event_value)
                   VALUES (?, ?, ?, ?)""",
                (exp_id, user_id, "aov", round(aov, 2)),
            )

    conn.commit()
    conn.close()
    print("DB initialized at", DB_PATH)


if __name__ == "__main__":
    init_db()
