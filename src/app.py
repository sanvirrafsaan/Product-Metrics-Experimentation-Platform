import sqlite3
from flask import Flask, g
import config

app = Flask(__name__)


app.config.from_mapping(
    DATABASE=config.DATABASE,
    SECRET_KEY=config.SECRET_KEY,
)

def get_db():
    if "db" not in g: 
        g.db = sqlite3.connect(app.config["DATABASE"])
        g.db.row_factory = sqlite3.Row
    return g.db

@app.teardown_appcontext
def close_db(_exc=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()

@app.get("/")
def index():
    return "Experimentation Platform OK"


if __name__ == "__main__":
    app.run(debug=True)