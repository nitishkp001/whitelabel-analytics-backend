from app.crud.csv_import import CSVImport
from app.db.database import initialize_database
import os

def test_database_setup():
    """Test database initialization"""
    print("\nTesting database setup...")
    
    # Initialize database
    success = initialize_database()
    if success:
        print("✓ Database initialized successfully")
    else:
        print("✗ Database initialization failed")
    
    return success

def test_platform_import():
    """Test importing platform configuration"""
    print("\nTesting platform import...")
    
    # Create test platform data
    test_data = """platform_name,revenue_share_percentage,effective_from
Apple,70.00,2023-01-01
Spotify,65.00,2023-01-01
YouTube,60.00,2023-01-01"""

    # Write test data to file
    test_file = "test_platforms.csv"
    with open(test_file, "w") as f:
        f.write(test_data)

    try:
        # Import platforms
        result = CSVImport.import_platforms_from_csv(test_file)
        
        # Print results
        print("\nPlatform Import Results:")
        print(f"Success: {result['success']}")
        print(f"Message: {result['message']}")
        print(f"Rows Processed: {result['rows_processed']}")
        
        if 'results' in result:
            print("\nPlatform Results:")
            for platform in result['results']:
                status = "✓" if platform['success'] else "✗"
                print(f"{status} {platform['platform']}")
                
        return result['success']
        
    except Exception as e:
        print(f"Error during platform import: {e}")
        return False
    finally:
        # Clean up test file
        if os.path.exists(test_file):
            os.remove(test_file)

def test_revenue_import():
    """Test importing revenue data"""
    print("\nTesting revenue import...")
    try:
        # Import revenue data
        result = CSVImport.import_revenue_from_csv('RevenueSheet.txt')
        
        # Print results
        print("\nRevenue Import Results:")
        print(f"Success: {result['success']}")
        print(f"Message: {result['message']}")
        print(f"Rows Processed: {result['rows_processed']}")
        
        if 'processing_stats' in result:
            print("\nProcessing Statistics:")
            for status, count in result['processing_stats'].items():
                status_symbol = "✓" if status == "PROCESSED" else "✗"
                print(f"{status_symbol} {status}: {count}")
        
        if 'view_refresh' in result:
            print("\nView Refresh Results:")
            for view, success in result['view_refresh'].items():
                status = "✓" if success else "✗"
                print(f"{status} {view}")
                
        return result['success']
                
    except Exception as e:
        print(f"Error during revenue import: {e}")
        return False

def main():
    """Run all tests"""
    print("Starting import tests...")
    
    # Test database setup
    if not test_database_setup():
        print("Database setup failed. Stopping tests.")
        return
        
    # Test platform import
    if not test_platform_import():
        print("Platform import failed. Continuing with revenue import...")
    
    # Test revenue import
    if not test_revenue_import():
        print("Revenue import failed.")
    else:
        print("\nAll tests completed!")

if __name__ == "__main__":
    main()
