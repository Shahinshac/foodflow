import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# Default to local SQLite database if DATABASE_URL is not set
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./foodflow.db")

# SQLAlchemy 2.0 requires 'postgresql://' instead of legacy 'postgres://'
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

if not DATABASE_URL.startswith("sqlite"):
    from urllib.parse import urlparse, parse_qs, urlencode, urlunparse
    u = urlparse(DATABASE_URL)
    qs = parse_qs(u.query)
    # Remove parameters that may cause issues with psycopg2 on Windows/libpq
    qs.pop("channel_binding", None)
    if "sslmode" not in qs and "neon.tech" in u.netloc:
        qs["sslmode"] = ["require"]
    new_query = urlencode(qs, doseq=True)
    DATABASE_URL = urlunparse((u.scheme, u.netloc, u.path, u.params, new_query, u.fragment))

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

# For PostgreSQL, enable connection pool pre-ping to gracefully handle disconnects
engine_kwargs = {"connect_args": connect_args}
if not DATABASE_URL.startswith("sqlite"):
    engine_kwargs.update({
        "pool_pre_ping": True,
        "pool_recycle": 300,
    })

engine = create_engine(DATABASE_URL, **engine_kwargs)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
