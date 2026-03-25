"""
Paths needed for sessions / flash messages. Environment variables.
"""
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATABASE = os.path.join(BASE_DIR, "data", "experiment.db")
# Dev only — use env var in production
SECRET_KEY = os.environ.get("SECRET_KEY", "dev-change-me")