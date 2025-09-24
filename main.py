from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
import asyncpg
import redis.asyncio as redis
import os

app = FastAPI()

# Отримуємо змінні оточення
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/postgres")
REDIS_ADDR = os.getenv("REDIS_ADDR", "redis://localhost:6379")

db_pool = None
rdb = None

@app.on_event("startup")
async def startup():
    global db_pool, rdb
    # Postgres pool
    db_pool = await asyncpg.create_pool(DATABASE_URL)
    # Redis client
    rdb = redis.from_url(REDIS_ADDR)

@app.get("/healthz")
async def healthz():
    return {"status": "ok"}

@app.get("/readyz")
async def readyz():
    try:
        async with db_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        await rdb.ping()
        return {"status": "ready"}
    except Exception as e:
        return {"status": "not ready", "error": str(e)}

@app.get("/status")
async def status():
    result = {"postgres": "ok", "redis": "ok"}
    try:
        async with db_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
    except Exception as e:
        result["postgres"] = f"error: {e}"

    try:
        await rdb.ping()
    except Exception as e:
        result["redis"] = f"error: {e}"

    return result

@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    html = """
    <html>
    <head>
      <title>Status Page</title>
      <style>
        body { font-family: sans-serif; margin: 2rem; }
        pre { background: #eee; padding: 1rem; }
      </style>
    </head>
    <body>
      <h1>Service Status</h1>
      <button onclick="check()">Check Backend</button>
      <pre id="output"></pre>

      <script>
        async function check() {
          const res = await fetch('/status');
          const data = await res.json();
          document.getElementById('output').innerText = JSON.stringify(data, null, 2);
        }
      </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html)
