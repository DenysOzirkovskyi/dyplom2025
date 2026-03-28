import logging
import os
import time
from contextlib import contextmanager
from datetime import datetime

import psycopg2
import redis
from fastapi import FastAPI, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse, Response
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from psycopg2.extras import RealDictCursor
from psycopg2.pool import SimpleConnectionPool


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger("queue-app")


REQUEST_COUNT = Counter(
    "fastapi_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status_code"],
)
REQUEST_LATENCY = Histogram(
    "fastapi_request_latency_seconds",
    "Latency of HTTP requests in seconds",
    ["method", "endpoint"],
)
REQUEST_ERRORS = Counter(
    "fastapi_request_errors_total",
    "Total failed HTTP requests",
    ["method", "endpoint"],
)


app = FastAPI(title="Queue Management System")
templates = Jinja2Templates(directory="templates")
app.mount("/static", StaticFiles(directory="static"), name="static")

db_pool: SimpleConnectionPool | None = None
redis_client: redis.Redis | None = None

VALID_STATUSES = {"new", "in_progress", "done"}


class TicketCreate(BaseModel):
    title: str
    description: str


class TicketUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    status: str | None = None


def db_settings() -> dict[str, str]:
    return {
        "dbname": os.getenv("POSTGRES_DB", "queue_db"),
        "user": os.getenv("POSTGRES_USER", "queue_user"),
        "password": os.getenv("POSTGRES_PASSWORD", "queue_password"),
        "host": os.getenv("POSTGRES_HOST", "db"),
        "port": os.getenv("POSTGRES_PORT", "5432"),
    }


def get_route_template(request: Request) -> str:
    route = request.scope.get("route")
    return getattr(route, "path", request.url.path)


def wait_for_dependencies(max_retries: int = 20, delay: int = 3) -> None:
    global redis_client

    for attempt in range(1, max_retries + 1):
        try:
            connection = psycopg2.connect(**db_settings())
            connection.close()

            redis_url = os.getenv("REDIS_URL", "redis://redis:6379/0")
            redis_client = redis.Redis.from_url(redis_url, decode_responses=True)
            redis_client.ping()

            logger.info("Database and Redis are available.")
            return
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "Dependency check failed on attempt %s/%s: %s",
                attempt,
                max_retries,
                exc,
            )
            time.sleep(delay)

    raise RuntimeError("Application dependencies did not become ready in time.")


def init_db() -> None:
    global db_pool

    if db_pool is None:
        settings = db_settings()
        db_pool = SimpleConnectionPool(1, 10, cursor_factory=RealDictCursor, **settings)

    create_table_sql = """
    CREATE TABLE IF NOT EXISTS tickets (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        description TEXT NOT NULL,
        status VARCHAR(20) NOT NULL DEFAULT 'new',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    """
    with get_db_cursor(commit=True) as cursor:
        cursor.execute(create_table_sql)

    logger.info("Database schema is ready.")


@contextmanager
def get_db_cursor(commit: bool = False):
    if db_pool is None:
        raise RuntimeError("Database pool is not initialized.")

    connection = db_pool.getconn()
    try:
        cursor = connection.cursor()
        yield cursor
        if commit:
            connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()
        db_pool.putconn(connection)


def fetch_tickets() -> list[dict]:
    with get_db_cursor() as cursor:
        cursor.execute(
            """
            SELECT id, title, description, status, created_at
            FROM tickets
            ORDER BY created_at DESC, id DESC
            """
        )
        tickets = cursor.fetchall()

    for ticket in tickets:
        if isinstance(ticket["created_at"], datetime):
            ticket["created_at"] = ticket["created_at"].strftime("%Y-%m-%d %H:%M:%S")
    return tickets


def get_ticket(ticket_id: int) -> dict:
    with get_db_cursor() as cursor:
        cursor.execute(
            """
            SELECT id, title, description, status, created_at
            FROM tickets
            WHERE id = %s
            """,
            (ticket_id,),
        )
        ticket = cursor.fetchone()

    if ticket is None:
        raise HTTPException(status_code=404, detail="Ticket not found")

    if isinstance(ticket["created_at"], datetime):
        ticket["created_at"] = ticket["created_at"].strftime("%Y-%m-%d %H:%M:%S")
    return ticket


@app.on_event("startup")
def startup_event() -> None:
    logger.info("Starting queue management application.")
    wait_for_dependencies()
    init_db()


@app.on_event("shutdown")
def shutdown_event() -> None:
    global db_pool, redis_client

    logger.info("Shutting down queue management application.")
    if db_pool is not None:
        db_pool.closeall()
        db_pool = None
    if redis_client is not None:
        redis_client.close()
        redis_client = None


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    if request.url.path == "/metrics":
        return await call_next(request)

    start_time = time.perf_counter()
    endpoint = get_route_template(request)

    try:
        response = await call_next(request)
    except Exception:
        REQUEST_ERRORS.labels(method=request.method, endpoint=endpoint).inc()
        REQUEST_COUNT.labels(method=request.method, endpoint=endpoint, status_code="500").inc()
        REQUEST_LATENCY.labels(method=request.method, endpoint=endpoint).observe(
            time.perf_counter() - start_time
        )
        logger.exception("Unhandled error for %s %s", request.method, request.url.path)
        raise

    if response.status_code >= 400:
        REQUEST_ERRORS.labels(method=request.method, endpoint=endpoint).inc()

    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=endpoint,
        status_code=str(response.status_code),
    ).inc()
    REQUEST_LATENCY.labels(method=request.method, endpoint=endpoint).observe(
        time.perf_counter() - start_time
    )
    return response


@app.get("/health")
def health() -> dict:
    database_ok = False
    redis_ok = False

    try:
        with get_db_cursor() as cursor:
            cursor.execute("SELECT 1;")
            cursor.fetchone()
        database_ok = True
    except Exception as exc:  # noqa: BLE001
        logger.error("Database health check failed: %s", exc)

    try:
        if redis_client is not None:
            redis_ok = bool(redis_client.ping())
    except Exception as exc:  # noqa: BLE001
        logger.error("Redis health check failed: %s", exc)

    status = "healthy" if database_ok and redis_ok else "degraded"
    return {
        "status": status,
        "database": database_ok,
        "redis": redis_ok,
    }


@app.get("/metrics")
def metrics() -> Response:
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/", response_class=HTMLResponse)
def dashboard(request: Request):
    tickets = fetch_tickets()
    return templates.TemplateResponse(
        "index.html",
        {
            "request": request,
            "tickets": tickets,
            "statuses": ["new", "in_progress", "done"],
        },
    )


@app.get("/create", response_class=HTMLResponse)
def create_ticket_page(request: Request):
    return templates.TemplateResponse("create.html", {"request": request})


@app.get("/tickets")
def list_tickets() -> list[dict]:
    return fetch_tickets()


@app.post("/tickets", status_code=201)
def create_ticket(ticket: TicketCreate):
    title_value = ticket.title.strip()
    description_value = ticket.description.strip()

    if not title_value or not description_value:
        raise HTTPException(status_code=400, detail="Title and description are required")

    with get_db_cursor(commit=True) as cursor:
        cursor.execute(
            """
            INSERT INTO tickets (title, description, status)
            VALUES (%s, %s, 'new')
            RETURNING id, title, description, status, created_at
            """,
            (title_value, description_value),
        )
        ticket = cursor.fetchone()

    logger.info("Created ticket %s", ticket["id"])
    ticket["created_at"] = ticket["created_at"].strftime("%Y-%m-%d %H:%M:%S")
    return ticket


@app.put("/tickets/{ticket_id}")
def update_ticket(ticket_id: int, payload: TicketUpdate):
    status = payload.status
    title = payload.title
    description = payload.description

    if status is not None and status not in VALID_STATUSES:
        raise HTTPException(status_code=400, detail="Invalid status value")

    existing = get_ticket(ticket_id)
    new_title = title.strip() if isinstance(title, str) and title.strip() else existing["title"]
    new_description = (
        description.strip()
        if isinstance(description, str) and description.strip()
        else existing["description"]
    )
    new_status = status or existing["status"]

    with get_db_cursor(commit=True) as cursor:
        cursor.execute(
            """
            UPDATE tickets
            SET title = %s, description = %s, status = %s
            WHERE id = %s
            RETURNING id, title, description, status, created_at
            """,
            (new_title, new_description, new_status, ticket_id),
        )
        updated = cursor.fetchone()

    logger.info("Updated ticket %s", ticket_id)
    updated["created_at"] = updated["created_at"].strftime("%Y-%m-%d %H:%M:%S")
    return updated


@app.delete("/tickets/{ticket_id}", status_code=204)
def delete_ticket(ticket_id: int) -> Response:
    with get_db_cursor(commit=True) as cursor:
        cursor.execute("DELETE FROM tickets WHERE id = %s RETURNING id", (ticket_id,))
        deleted = cursor.fetchone()

    if deleted is None:
        raise HTTPException(status_code=404, detail="Ticket not found")

    logger.info("Deleted ticket %s", ticket_id)
    return Response(status_code=204)


@app.post("/tickets/ui")
def create_ticket_from_ui(title: str = Form(...), description: str = Form(...)):
    title_value = title.strip()
    description_value = description.strip()

    if not title_value or not description_value:
        raise HTTPException(status_code=400, detail="Title and description are required")

    with get_db_cursor(commit=True) as cursor:
        cursor.execute(
            """
            INSERT INTO tickets (title, description, status)
            VALUES (%s, %s, 'new')
            """,
            (title_value, description_value),
        )

    logger.info("Created ticket from UI")
    return RedirectResponse(url="/", status_code=303)


@app.post("/tickets/{ticket_id}/status")
def update_ticket_status_from_ui(ticket_id: int, status: str = Form(...)):
    if status not in VALID_STATUSES:
        raise HTTPException(status_code=400, detail="Invalid status value")

    with get_db_cursor(commit=True) as cursor:
        cursor.execute(
            "UPDATE tickets SET status = %s WHERE id = %s RETURNING id",
            (status, ticket_id),
        )
        updated = cursor.fetchone()

    if updated is None:
        raise HTTPException(status_code=404, detail="Ticket not found")

    logger.info("Updated ticket %s status to %s", ticket_id, status)
    return RedirectResponse(url="/", status_code=303)


@app.post("/tickets/{ticket_id}/delete")
def delete_ticket_from_ui(ticket_id: int):
    with get_db_cursor(commit=True) as cursor:
        cursor.execute("DELETE FROM tickets WHERE id = %s RETURNING id", (ticket_id,))
        deleted = cursor.fetchone()

    if deleted is None:
        raise HTTPException(status_code=404, detail="Ticket not found")

    logger.info("Deleted ticket %s from UI", ticket_id)
    return RedirectResponse(url="/", status_code=303)
