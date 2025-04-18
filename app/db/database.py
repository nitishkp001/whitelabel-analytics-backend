import os
from typing import Dict, Any, List, Optional
from contextlib import contextmanager
import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Database configuration
DB_CONFIG = {
    "dbname": os.getenv("DB_NAME", "royalty_db"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", ""),
    "host": os.getenv("DB_HOST", "localhost"),
    "port": os.getenv("DB_PORT", "5432")
}

@contextmanager
def get_db():
    """Database connection context manager"""
    conn = psycopg.connect(**DB_CONFIG)
    try:
        yield conn
    finally:
        conn.close()

def execute_query(conn: psycopg.Connection, query: str, params: Dict[str, Any] = None) -> List[Dict[str, Any]]:
    """Execute a query and return results as a list of dictionaries"""
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(query, params or {})
        return cur.fetchall()

def execute_one(conn: psycopg.Connection, query: str, params: Dict[str, Any] = None) -> Optional[Dict[str, Any]]:
    """Execute a query and return a single result as a dictionary"""
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(query, params or {})
        return cur.fetchone()

def initialize_database():
    """Initialize database with schema and tables"""
    try:
        # Read SQL file
        with open('db_setup.sql', 'r') as file:
            sql_script = file.read()
        
        # Connect and execute
        with get_db() as conn:
            with conn.cursor() as cur:
                # Execute all statements in the script
                cur.execute(sql_script)
            conn.commit()
            
            # Verify setup by checking schemas
            schemas = execute_query(conn, """
                SELECT schema_name 
                FROM information_schema.schemata 
                WHERE schema_name IN ('whitelabel', 'analytics');
            """)
            print(f"Created schemas: {[s['schema_name'] for s in schemas]}")
            
            # Check whitelabel tables
            tables = execute_query(conn, """
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'whitelabel';
            """)
            print(f"Whitelabel tables: {[t['table_name'] for t in tables]}")
            
            # Check analytics tables
            tables = execute_query(conn, """
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'analytics';
            """)
            print(f"Analytics tables: {[t['table_name'] for t in tables]}")
            
            print("Database initialized successfully!")
            return True
            
    except Exception as e:
        print(f"Error initializing database: {str(e)}")
        return False

if __name__ == "__main__":
    # Initialize database when run directly
    initialize_database()
