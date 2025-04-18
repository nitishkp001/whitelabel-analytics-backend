# Royalty Analytics API

A FastAPI service for music royalty analytics and reporting.

## Features

- Revenue overview analytics
- Artist performance metrics
- Platform-wise analytics
- Monthly royalty statements
- Data validation and error handling
- CSV data import support

## Prerequisites

- Python 3.8+
- PostgreSQL database
- Poetry (optional, for dependency management)

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd royalty-analytics
```

2. Create and activate a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows, use: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

## Database Setup

1. Configure database connection:
```bash
# Copy example config
cp .env.example .env

# Edit database credentials
nano .env
```

2. Initialize database:
```bash
# This will:
# - Create database if it doesn't exist
# - Create schemas (whitelabel, analytics)
# - Set up all required tables
# - Create materialized views
# - Initialize sample data
python setup_database.py
```

3. Verify setup:
```sql
psql -d royalty_db -c "\dn"  -- List schemas
psql -d royalty_db -c "\dt whitelabel.*"  -- List whitelabel tables
psql -d royalty_db -c "\dt analytics.*"  -- List analytics tables
```

## Running the Service

1. Start the FastAPI server:
```bash
uvicorn main:app --reload
```

2. Access the API documentation:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Data Import

### Revenue Sheet Format
The service accepts revenue data in the following CSV format (RevenueSheet.txt):
```csv
service,month,isrc,product,song_name,artist,album,label,file_name,country,total,royality,userid
Apple,Apr/23,INK782201237,Cloud 9,Amrit Nagra,,Abhi,Apple,CA,1,0.1608771378,48
```

Key fields:
- service: Platform name (e.g., Apple)
- month: Month and year (e.g., Apr/23)
- isrc: Unique identifier for the song
- total: Number of plays
- royality: Revenue amount
- userid: Artist ID in the system

### Import Methods

1. Using the API:
```bash
# Import revenue data from RevenueSheet.txt
curl -X POST "http://localhost:8000/api/v1/import/csv/revenue/path" \
    -H "Content-Type: application/json" \
    -d '{"file_path": "/path/to/RevenueSheet.txt"}'
```

2. Using test script:
```bash
python test_import.py
```

### Import Process

1. The import process follows these steps:
   - Reads the RevenueSheet.txt file
   - Validates artist IDs against the database
   - Stages the data in stg_revenue_import table
   - Processes staged data and calculates royalties
   - Updates materialized views

2. Status tracking:
   - PENDING: Initial state
   - PROCESSED: Successfully imported
   - FAILED: Import failed (with error message)

3. Validation checks:
   - Valid ISRC codes
   - Existing artist IDs
   - Valid platform configuration
   - Active song status

## API Reference

### 1. Artist Earnings API

Fetch monthly earnings metrics for an artist.

**Endpoint:** `GET /api/v1/artists/{artist_id}/earnings`

**Query Parameters:**
- year (optional): Filter by year (e.g., 2023)
- month (optional): Filter by month (e.g., "Apr")

**Example Response:**
```json
{
  "year": 2023,
  "month": "Apr",
  "artist_id": 48,
  "artist_name": "Amrit Nagra",
  "total_plays": 2,
  "total_revenue": 0.663721,
  "total_royalties": 0.464605,
  "avg_royalty_percentage": 70.00,
  "unique_songs": 1,
  "platform_count": 1
}
```

### 2. Platform Revenue API

Get revenue breakdown by platform.

**Endpoint:** `GET /api/v1/platforms/revenue`

**Query Parameters:**
- year (optional): Filter by year (e.g., 2023)
- month (optional): Filter by month (e.g., "Apr")
- platform_name (optional): Filter by platform (e.g., "Apple")

**Example Response:**
```json
{
  "year": 2023,
  "month": "Apr",
  "platform_name": "Apple",
  "revenue_share_percentage": 70.00,
  "songs_played": 180,
  "unique_artists": 24,
  "total_plays": 200,
  "total_revenue": 45.67,
  "total_royalties": 31.97
}
```

### 3. Artist Performance API

Get song-level performance metrics for an artist.

**Endpoint:** `GET /api/v1/artists/{artist_id}/performance`

**Query Parameters:**
- year (optional): Filter by year (e.g., 2023)
- month (optional): Filter by month (e.g., "Apr")
- isrc (optional): Filter by song ISRC

**Example Response:**
```json
{
  "year": 2023,
  "month": "Apr",
  "artist_id": 48,
  "artist_name": "Amrit Nagra",
  "song_id": 1,
  "song_name": "Cloud 9",
  "isrc": "INK782201237",
  "total_plays": 2,
  "total_revenue": 0.663721,
  "total_royalties": 0.464605,
  "platform_count": 1
}
```

### 4. Label Performance API

Get revenue and performance metrics by label.

**Endpoint:** `GET /api/v1/labels/performance`

**Query Parameters:**
- year (optional): Filter by year (e.g., 2023)
- month (optional): Filter by month (e.g., "Apr")
- label_id (optional): Filter by specific label

**Example Response:**
```json
{
  "year": 2023,
  "month": "Apr",
  "label_id": 1,
  "label_name": "Abhi",
  "unique_artists": 3,
  "unique_songs": 5,
  "total_plays": 150,
  "total_revenue": 35.67,
  "total_royalties": 24.97
}
```

### 5. Geographic Analysis API

Get revenue and performance metrics by geography.

**Endpoint:** `GET /api/v1/analytics/geography`

**Query Parameters:**
- year (optional): Filter by year (e.g., 2023)
- month (optional): Filter by month (e.g., "Apr")
- country_code (optional): Filter by country (e.g., "CA")
- isrc (optional): Filter by song ISRC

**Example Response:**
```json
{
  "year": 2023,
  "month": "Apr",
  "isrc": "INK782201237",
  "song_name": "Cloud 9",
  "artist_name": "Amrit Nagra",
  "country_code": "CA",
  "region": "North America",
  "platform_name": "Apple",
  "total_plays": 2,
  "total_revenue": 0.663721,
  "total_royalties": 0.464605
}
```

### 6. Artist Platform Label Matrix API

Get cross-analysis of artists across platforms and labels.

**Endpoint:** `GET /api/v1/analytics/platform-label`

**Query Parameters:**
- year (optional): Filter by year (e.g., 2023)
- month (optional): Filter by month (e.g., "Apr")
- artist_id (optional): Filter by artist
- platform_name (optional): Filter by platform
- label_name (optional): Filter by label

**Example Response:**
```json
{
  "year": 2023,
  "month": "Apr",
  "artist_id": 48,
  "artist_name": "Amrit Nagra",
  "platform_name": "Apple",
  "label_name": "Abhi",
  "unique_songs": 1,
  "total_plays": 2,
  "total_revenue": 0.663721,
  "total_royalties": 0.464605
}
```

## Database Schema

### Whitelabel Schema
Tables in `whitelabel` schema:
```sql
label:
  - label_id (PK)
  - label_name
  - created_at

artist:  
  - artist_id (PK) - matches userid from RevenueSheet
  - artist_name
  - payment_threshold
  - created_at

song:
  - song_id (PK)
  - isrc
  - title
  - artist_id (FK)
  - label_id (FK)
  - status
  - created_at
```

### Analytics Schema
Tables in `analytics` schema:
```sql
platform_config:
  - platform_id (PK)
  - platform_name
  - revenue_share_percentage
  - effective_from
  - effective_to
  - is_active

fact_monthly_revenue:
  - revenue_id, year (PK)
  - month
  - song_id (FK)
  - platform_id (FK)
  - geography_id (FK)
  - artist_id (FK)
  - total_plays
  - revenue_amount
  - royalty_amount
  - created_at

stg_revenue_import:
  - id (PK)
  - month_year
  - platform
  - isrc
  - plays
  - revenue
  - artist_id
  - status
  - error_message
  - created_at
```

### Materialized Views
```sql
mv_revenue_overview:
  Monthly aggregated revenue metrics

mv_artist_dashboard:
  Individual record-level artist metrics

mv_platform_analytics:
  Platform-wise revenue and usage analytics

mv_artist_earnings:
  Monthly earnings aggregated by artist

mv_platform_revenue:
  Revenue breakdown by platform

mv_artist_performance:
  Song-level performance metrics by artist

mv_label_performance:
  Revenue and performance by label

mv_artist_platform_label:
  Cross-analysis matrix of artists, platforms, and labels

mv_isrc_geo_platform:
  Geographic distribution of plays and revenue
```

## Development

1. Install development dependencies:
```bash
pip install -r requirements-dev.txt
```

2. Format code:
```bash
black app/
```

3. Run linting:
```bash
flake8 app/
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
