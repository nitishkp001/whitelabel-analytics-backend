from psycopg import OperationalError
import psycopg
import os
from dotenv import load_dotenv
from app.db.database import initialize_database, DB_CONFIG

def create_database():
    """Create the database if it doesn't exist"""
    try:
        # Load environment variables
        load_dotenv()
        
        # Get database name
        db_name = DB_CONFIG["dbname"]
        
        # Create connection config without database
        conn_config = DB_CONFIG.copy()
        conn_config["dbname"] = "postgres"  # Connect to default database
        
        # Connect to PostgreSQL
        conn = psycopg.connect(**conn_config)
        conn.autocommit = True
        
        try:
            # Try to create database
            with conn.cursor() as cur:
                # Check if database exists
                cur.execute(f"SELECT 1 FROM pg_database WHERE datname = %s", (db_name,))
                exists = cur.fetchone()
                
                if not exists:
                    print(f"Creating database {db_name}...")
                    cur.execute(f'CREATE DATABASE {db_name}')
                    print(f"Database {db_name} created successfully!")
                else:
                    print(f"Database {db_name} already exists.")
                    
        finally:
            conn.close()
            
        return True
        
    except Exception as e:
        print(f"Error creating database: {str(e)}")
        return False

def main():
    """Main setup function"""
    print("Starting database setup...")
    
    # Create database
    if create_database():
        # Initialize schema and tables
        print("\nInitializing database schema...")
        if initialize_database():
            print("\nSetup completed successfully!")
        else:
            print("\nError initializing database schema.")
    else:
        print("\nError creating database.")

if __name__ == "__main__":
    main()
