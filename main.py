import os
import time
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
import psycopg2
from psycopg2 import OperationalError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def wait_for_postgres(max_retries=5, delay=5):
    """
    Attempts to connect to PostgreSQL with backoff to handle container race conditions.
    """
    db_user = os.getenv("POSTGRES_USER", "postgres")
    db_password = os.getenv("POSTGRES_PASSWORD", "postgres")
    db_name = os.getenv("POSTGRES_DB", "postgres")
    db_host = os.getenv("POSTGRES_HOST", "db")
    
    retries = 0
    while retries < max_retries:
        try:
            logger.info(f"Attempting DB connection (attempt {retries + 1}/{max_retries})...")
            # Connect temporarily to test standard readiness 
            conn = psycopg2.connect(
                dbname=db_name,
                user=db_user,
                password=db_password,
                host=db_host
            )
            conn.close()
            logger.info("Database connection successful!")
            return True
        except OperationalError as e:
            logger.warning(f"Database connection failed. Retrying in {delay} seconds...")
            retries += 1
            time.sleep(delay)
            
    return False

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting up FastAPI application...")
    if not wait_for_postgres():
        logger.error("Could not establish a database connection. Starting anyway, but some routes may fail.")
        # Alternatively: raise RuntimeError("Database connection required") to hard-crash on failure

    # Add any extra initialization logic here (e.g. creating SQLAlchemy engine)
    
    yield
    
    logger.info("Shutting down application...")

app = FastAPI(lifespan=lifespan)

@app.get("/")
def read_root():
    return {"message": "Hello from your diploma project API!"}

@app.get("/health")
def healthcheck():
    return {"status": "healthy"}
