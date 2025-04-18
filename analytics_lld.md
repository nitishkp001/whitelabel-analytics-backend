# Royalty Analytics System - Low Level Design

## 1. Core Schema Design

### 1.1 Fact Tables
```sql
-- Monthly Revenue Facts
CREATE TABLE fact_monthly_revenue (
    revenue_id BIGSERIAL PRIMARY KEY,
    year INT NOT NULL,
    month VARCHAR(3) NOT NULL,
    song_id INT NOT NULL,
    platform_id INT NOT NULL,
    artist_id INT NOT NULL,
    total_plays INT NOT NULL,
    revenue_amount DECIMAL(15,6) NOT NULL,
    royalty_amount DECIMAL(15,6) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_amounts CHECK (royalty_amount <= revenue_amount)
) PARTITION BY RANGE (year);

-- Summary Tables
CREATE MATERIALIZED VIEW mv_artist_earnings AS
SELECT 
    fr.year,
    fr.month,
    wa.artist_id,
    wa.artist_name,
    wl.label_name,
    COUNT(DISTINCT ws.song_id) as song_count,
    COUNT(DISTINCT fr.platform_id) as platform_count,
    SUM(fr.total_plays) as play_count,
    SUM(fr.revenue_amount) as gross_revenue,
    SUM(fr.royalty_amount) as artist_royalty,
    ROUND(SUM(fr.royalty_amount) * 100.0 / NULLIF(SUM(fr.revenue_amount), 0), 2) as royalty_percentage,
    MIN(fr.created_at) as earliest_record,
    MAX(fr.created_at) as latest_record
FROM fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN whitelabel.artist wa ON ws.artist_id = wa.artist_id
JOIN whitelabel.label wl ON ws.label_id = wl.label_id
WHERE ws.status = 'Released'
GROUP BY fr.year, fr.month, wa.artist_id, wa.artist_name, wl.label_name;
```

### 1.2 Platform Configuration
```sql
-- Platform revenue share configuration
CREATE TABLE platform_config (
    platform_id SERIAL PRIMARY KEY,
    platform_name VARCHAR(100) NOT NULL,
    revenue_share_percentage DECIMAL(5,2) NOT NULL,
    effective_from DATE NOT NULL,
    effective_to DATE,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT valid_share CHECK (revenue_share_percentage BETWEEN 0 AND 100)
);

-- Note: All song, artist, and label information comes from whitelabel schema:
-- whitelabel.song: Contains ISRC and song details
-- whitelabel.artist: Contains artist information
-- whitelabel.label: Contains label information
-- whitelabel.artist_label: Contains artist-label relationships
```

## 2. ETL Processes

### 2.1 Revenue Import Process
```sql
-- Staging table for raw data
CREATE TABLE stg_revenue_import (
    id BIGSERIAL PRIMARY KEY,
    month_year VARCHAR(7),
    platform VARCHAR(100),
    isrc VARCHAR(12),
    plays INT,
    revenue DECIMAL(15,6),
    status VARCHAR(20) DEFAULT 'PENDING',
    error_message TEXT
);

-- ISRC Mapping function
CREATE OR REPLACE FUNCTION get_song_details(p_isrc VARCHAR(12))
RETURNS TABLE (
    song_id INT,
    artist_id INT,
    label_id INT,
    title VARCHAR(255),
    artist_name VARCHAR(255),
    label_name VARCHAR(100)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.song_id,
        s.artist_id,
        s.label_id,
        s.title,
        a.artist_name,
        l.label_name
    FROM whitelabel.song s
    JOIN whitelabel.artist a ON s.artist_id = a.artist_id
    JOIN whitelabel.label l ON s.label_id = l.label_id
    WHERE s.isrc = p_isrc
    AND s.status = 'Released';
END;
$$ LANGUAGE plpgsql;

-- Revenue processing function
CREATE OR REPLACE PROCEDURE process_revenue_import()
LANGUAGE plpgsql AS $$
BEGIN
    -- Transform and load revenue data
    WITH song_mappings AS (
        SELECT 
            s.id as staging_id,
            sd.song_id,
            sd.artist_id,
            sd.label_id,
            sd.title,
            sd.artist_name,
            sd.label_name
        FROM stg_revenue_import s
        CROSS JOIN LATERAL get_song_details(s.isrc) sd
        WHERE s.status = 'PENDING'
    )
    INSERT INTO fact_monthly_revenue (
        year, month, song_id, platform_id, artist_id,
        total_plays, revenue_amount, royalty_amount
    )
    SELECT 
        EXTRACT(YEAR FROM TO_DATE(s.month_year, 'YYYY-MM')) as year,
        TO_CHAR(TO_DATE(s.month_year, 'YYYY-MM'), 'Mon') as month,
        sm.song_id,
        pc.platform_id,
        sm.artist_id,
        s.plays,
        s.revenue,
        s.revenue * (pc.revenue_share_percentage/100.0) as royalty
    FROM stg_revenue_import s
    JOIN song_mappings sm ON s.id = sm.staging_id
    JOIN platform_config pc ON s.platform = pc.platform_name
        AND TO_DATE(s.month_year, 'YYYY-MM') >= pc.effective_from
        AND (pc.effective_to IS NULL OR TO_DATE(s.month_year, 'YYYY-MM') <= pc.effective_to)
    WHERE s.status = 'PENDING'
    AND pc.is_active = true;
    
    -- Mark processed records
    UPDATE stg_revenue_import 
    SET status = 'PROCESSED'
    WHERE status = 'PENDING';
END;
$$;
```

## 3. Analytics Views

### 3.1 Revenue Analysis
```sql
-- Platform Performance
CREATE MATERIALIZED VIEW mv_platform_revenue AS
SELECT 
    fr.year,
    fr.month,
    pc.platform_name,
    SUM(fr.total_plays) as total_plays,
    SUM(fr.revenue_amount) as total_revenue,
    COUNT(DISTINCT ws.song_id) as unique_songs,
    COUNT(DISTINCT ws.artist_id) as unique_artists,
    COUNT(DISTINCT ws.label_id) as unique_labels
FROM fact_monthly_revenue fr
JOIN platform_config pc ON fr.platform_id = pc.platform_id
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
WHERE pc.is_active = true
GROUP BY fr.year, fr.month, pc.platform_name;

-- Artist Performance by Label
CREATE MATERIALIZED VIEW mv_artist_performance AS
SELECT 
    fr.year,
    fr.month,
    wa.artist_id,
    wa.artist_name,
    wl.label_id,
    wl.label_name,
    COUNT(DISTINCT ws.song_id) as song_count,
    COUNT(DISTINCT fr.platform_id) as platform_count,
    SUM(fr.total_plays) as total_plays,
    SUM(fr.revenue_amount) as gross_revenue,
    SUM(fr.royalty_amount) as royalty_earned,
    ROUND(SUM(fr.royalty_amount) * 100.0 / NULLIF(SUM(fr.revenue_amount), 0), 2) as royalty_percentage
FROM fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN whitelabel.artist wa ON ws.artist_id = wa.artist_id
JOIN whitelabel.label wl ON ws.label_id = wl.label_id
WHERE ws.status = 'Released'
GROUP BY fr.year, fr.month, wa.artist_id, wa.artist_name, wl.label_id, wl.label_name;
```

### 3.2 Royalty Reports
```sql
-- Monthly Royalty Statement
CREATE OR REPLACE FUNCTION generate_royalty_statement(
    p_artist_id INT,
    p_year INT,
    p_month VARCHAR(3)
) RETURNS TABLE (
    song_title VARCHAR(255),
    isrc VARCHAR(12),
    label_name VARCHAR(100),
    platform VARCHAR(100),
    play_count INT,
    gross_revenue DECIMAL(15,6),
    royalty_amount DECIMAL(15,6),
    revenue_share_percentage DECIMAL(5,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ws.title,
        ws.isrc,
        wl.label_name,
        pc.platform_name,
        fr.total_plays,
        fr.revenue_amount,
        fr.royalty_amount,
        pc.revenue_share_percentage
    FROM fact_monthly_revenue fr
    JOIN whitelabel.song ws ON fr.song_id = ws.song_id
    JOIN whitelabel.label wl ON ws.label_id = wl.label_id
    JOIN platform_config pc ON fr.platform_id = pc.platform_id
    WHERE ws.artist_id = p_artist_id
    AND ws.status = 'Released'
    AND fr.year = p_year
    AND fr.month = p_month
    AND pc.is_active = true
    ORDER BY fr.revenue_amount DESC;
END;
$$ LANGUAGE plpgsql;

-- Payment Processing View
CREATE VIEW v_payment_eligible_artists AS
SELECT 
    wa.artist_id,
    wa.artist_name,
    wl.label_name,
    SUM(fr.royalty_amount) as unpaid_royalties,
    COUNT(DISTINCT ws.song_id) as song_count,
    COUNT(DISTINCT fr.platform_id) as platform_count
FROM fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN whitelabel.artist wa ON ws.artist_id = wa.artist_id
JOIN whitelabel.label wl ON ws.label_id = wl.label_id
WHERE ws.status = 'Released'
AND NOT EXISTS (
    SELECT 1 FROM payment_history ph
    WHERE ph.artist_id = wa.artist_id
    AND ph.year = fr.year
    AND ph.month = fr.month
)
GROUP BY wa.artist_id, wa.artist_name, wl.label_name
HAVING SUM(fr.royalty_amount) >= wa.payment_threshold;
```

## 4. Performance Optimization

### 4.1 Optimized Indexes
```sql
-- Fact table indexes for revenue analysis
CREATE INDEX idx_revenue_date ON fact_monthly_revenue(year, month) 
INCLUDE (song_id, platform_id, total_plays, revenue_amount, royalty_amount);

CREATE INDEX idx_revenue_song ON fact_monthly_revenue(song_id, year, month) 
INCLUDE (total_plays, revenue_amount, royalty_amount);

CREATE INDEX idx_revenue_platform ON fact_monthly_revenue(platform_id, year, month) 
INCLUDE (total_plays, revenue_amount, royalty_amount);

-- Partial indexes for current data
CREATE INDEX idx_revenue_current_year ON fact_monthly_revenue(year, month)
WHERE year = EXTRACT(YEAR FROM CURRENT_DATE);

-- Platform config indexes
CREATE UNIQUE INDEX idx_platform_name ON platform_config(platform_name) 
WHERE is_active = true;

CREATE INDEX idx_platform_dates ON platform_config(effective_from, effective_to)
WHERE is_active = true;

-- Materialized view indexes for performance
CREATE INDEX idx_mv_artist_earnings ON mv_artist_earnings(year, month, artist_id);
CREATE INDEX idx_mv_platform_revenue ON mv_platform_revenue(year, month, platform_name);
CREATE INDEX idx_mv_isrc_performance ON mv_isrc_performance(year, month, isrc);
CREATE INDEX idx_mv_label_performance ON mv_label_performance(year, month, label_name);
CREATE INDEX idx_mv_artist_dashboard ON mv_artist_dashboard(artist_id, year, month);
CREATE INDEX idx_mv_platform_analytics ON mv_platform_analytics(platform_name, year, month);

-- Cross-dimensional analysis indexes
CREATE INDEX idx_mv_label_platform ON mv_label_platform_performance(label_name, platform_name, year, month);
CREATE INDEX idx_mv_artist_platform ON mv_artist_platform_label(artist_name, platform_name, year, month);
CREATE INDEX idx_mv_isrc_geo ON mv_isrc_geo_platform(isrc, region, platform_name, year, month);
```

### 4.2 Partitioning Strategy
```sql
-- Create yearly partitions
CREATE TABLE fact_monthly_revenue_2024 
PARTITION OF fact_monthly_revenue
FOR VALUES FROM (2024) TO (2025);

CREATE TABLE fact_monthly_revenue_2025 
PARTITION OF fact_monthly_revenue
FOR VALUES FROM (2025) TO (2026);
```

## 5. Implementation Steps

1. Setup Core Schema:
   - Create dimension tables
   - Create fact tables with partitions
   - Set up materialized views

2. ETL Implementation:
   - Implement revenue import process
   - Set up data validation rules
   - Configure error handling

3. Analytics Setup:
   - Create performance views
   - Set up royalty calculation logic
   - Implement reporting functions

4. Maintenance:
   - Schedule view refreshes
   - Monitor performance
   - Manage partitions

## 6. Sample Data and Testing

### 6.1 Example Data
```sql
-- Insert sample platforms
INSERT INTO platform_config (
    platform_name, 
    revenue_share_percentage, 
    effective_from,
    is_active
) VALUES
('Spotify', 70.00, '2025-01-01', true),
('Apple Music', 70.00, '2025-01-01', true),
('YouTube Music', 55.00, '2025-01-01', true);

-- Note: The following data would come from whitelabel schema:
/*
-- Label data
INSERT INTO whitelabel.label (label_name) VALUES
('Sony Music'), ('Universal Music'), ('Warner Music');

-- Artist data
INSERT INTO whitelabel.artist (artist_name) VALUES
('John Smith'), ('Jane Doe'), ('Rock Band');

-- Song data
INSERT INTO whitelabel.song (
    isrc, title, artist_id, label_id, status
) VALUES
('USUM71307667', 'Summer Hits', 1, 1, 'Released'),
('GBAYE0601498', 'Winter Blues', 1, 1, 'Released'),
('USRC17607839', 'Rock Anthem', 2, 2, 'Released');
*/

-- Insert sample revenue data
INSERT INTO fact_monthly_revenue (
    year, month, song_id, platform_id, artist_id, 
    total_plays, revenue_amount, royalty_amount
) VALUES
(2025, 'Jan', 1, 1, 1, 10000, 500.00, 350.00),
(2025, 'Jan', 2, 2, 1, 8000, 400.00, 280.00),
(2025, 'Jan', 3, 1, 2, 15000, 750.00, 525.00);
```

### 6.2 Test Queries
```sql
-- Test revenue calculation by artist and platform
SELECT 
    wa.artist_name,
    pc.platform_name,
    COUNT(DISTINCT ws.song_id) as songs,
    SUM(fr.total_plays) as plays,
    SUM(fr.revenue_amount) as revenue,
    SUM(fr.royalty_amount) as royalty,
    ROUND(SUM(fr.royalty_amount) * 100.0 / NULLIF(SUM(fr.revenue_amount), 0), 2) as effective_rate
FROM fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN whitelabel.artist wa ON ws.artist_id = wa.artist_id
JOIN platform_config pc ON fr.platform_id = pc.platform_id
WHERE ws.status = 'Released'
AND pc.is_active = true
GROUP BY wa.artist_name, pc.platform_name
ORDER BY revenue DESC;

-- Test artist performance by song
SELECT 
    ws.title,
    wa.artist_name,
    wl.label_name,
    SUM(fr.total_plays) as total_plays,
    SUM(fr.revenue_amount) as total_revenue,
    SUM(fr.royalty_amount) as total_royalties,
    COUNT(DISTINCT fr.platform_id) as platform_count,
    ROUND(SUM(fr.royalty_amount) * 100.0 / NULLIF(SUM(fr.revenue_amount), 0), 2) as royalty_percentage
FROM fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN whitelabel.artist wa ON ws.artist_id = wa.artist_id
JOIN whitelabel.label wl ON ws.label_id = wl.label_id
WHERE ws.status = 'Released'
AND ws.artist_id = 1
GROUP BY ws.title, wa.artist_name, wl.label_name
ORDER BY total_revenue DESC;
```

## 7. Dashboard Views

### 7.1 Revenue Overview
```sql
CREATE MATERIALIZED VIEW mv_revenue_overview AS
SELECT
    fr.year,
    fr.month,
    COUNT(DISTINCT ws.artist_id) as active_artists,
    COUNT(DISTINCT ws.label_id) as active_labels,
    COUNT(DISTINCT ws.song_id) as active_songs,
    COUNT(DISTINCT pc.platform_id) as active_platforms,
    SUM(fr.total_plays) as total_plays,
    SUM(fr.revenue_amount) as total_revenue,
    SUM(fr.royalty_amount) as total_royalties,
    ROUND(SUM(fr.royalty_amount) * 100.0 / NULLIF(SUM(fr.revenue_amount), 0), 2) as avg_royalty_rate,
    ROUND(SUM(fr.revenue_amount) / NULLIF(SUM(fr.total_plays), 0), 6) as avg_revenue_per_play,
    MIN(fr.created_at) as earliest_record,
    MAX(fr.created_at) as latest_record
FROM fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN platform_config pc ON fr.platform_id = pc.platform_id
WHERE ws.status = 'Released'
AND pc.is_active = true
GROUP BY fr.year, fr.month;

-- Refresh Schedule: Daily at 00:01
SELECT cron.schedule('refresh_revenue_overview', '1 0 * * *', 
    'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_revenue_overview');
```

### 7.2 Artist Dashboard
```sql
CREATE MATERIALIZED VIEW mv_artist_dashboard AS
WITH artist_stats AS (
    SELECT 
        ws.artist_id,
        wa.artist_name,
        wl.label_id,
        wl.label_name,
        fr.year,
        fr.month,
        COUNT(DISTINCT ws.song_id) as songs,
        COUNT(DISTINCT fr.platform_id) as platforms,
        SUM(fr.total_plays) as plays,
        SUM(fr.revenue_amount) as revenue,
        SUM(fr.royalty_amount) as royalty
    FROM fact_monthly_revenue fr
    JOIN whitelabel.song ws ON fr.song_id = ws.song_id
    JOIN whitelabel.artist wa ON ws.artist_id = wa.artist_id
    JOIN whitelabel.label wl ON ws.label_id = wl.label_id
    WHERE ws.status = 'Released'
    GROUP BY ws.artist_id, wa.artist_name, wl.label_id, wl.label_name, fr.year, fr.month
),
previous_month AS (
    SELECT 
        artist_id,
        plays as prev_plays,
        revenue as prev_revenue,
        songs as prev_songs
    FROM artist_stats
    WHERE (year, month) = (
        SELECT year, month
        FROM artist_stats
        ORDER BY year DESC, month DESC
        OFFSET 1 LIMIT 1
    )
)
SELECT 
    ast.artist_id,
    ast.artist_name,
    ast.label_id,
    ast.label_name,
    ast.year,
    ast.month,
    ast.songs,
    ast.platforms,
    ast.plays,
    ast.revenue,
    ast.royalty,
    ROUND(ast.royalty * 100.0 / NULLIF(ast.revenue, 0), 2) as royalty_percentage,
    ROUND(((ast.plays - pm.prev_plays) * 100.0 / NULLIF(pm.prev_plays, 0)), 2) as plays_growth,
    ROUND(((ast.revenue - pm.prev_revenue) * 100.0 / NULLIF(pm.prev_revenue, 0)), 2) as revenue_growth,
    ROUND(((ast.songs - pm.prev_songs) * 100.0 / NULLIF(pm.prev_songs, 0)), 2) as songs_growth
FROM artist_stats ast
LEFT JOIN previous_month pm ON ast.artist_id = pm.artist_id;
```

### 7.3 Label Analytics
```sql
CREATE MATERIALIZED VIEW mv_label_performance AS
WITH label_metrics AS (
    SELECT 
        wl.label_id,
        wl.label_name,
        fr.year,
        fr.month,
        COUNT(DISTINCT ws.artist_id) as artist_count,
        COUNT(DISTINCT ws.song_id) as song_count,
        SUM(fr.total_plays) as total_plays,
        SUM(fr.revenue_amount) as total_revenue,
        SUM(fr.royalty_amount) as total_royalties
    FROM fact_monthly_revenue fr
    JOIN whitelabel.song ws ON fr.song_id = ws.song_id
    JOIN whitelabel.label wl ON ws.label_id = wl.label_id
    WHERE ws.status = 'Released'
    GROUP BY wl.label_id, wl.label_name, fr.year, fr.month
)
SELECT 
    *,
    ROUND(total_royalties * 100.0 / NULLIF(total_revenue, 0), 2) as royalty_percentage,
    ROUND(total_revenue::numeric / NULLIF(total_plays, 0), 6) as revenue_per_play
FROM label_metrics;
```

### 7.4 ISRC Analytics
```sql
CREATE MATERIALIZED VIEW mv_isrc_performance AS
WITH song_metrics AS (
    SELECT 
        ws.isrc,
        ws.title,
        wa.artist_name,
        wl.label_name,
        fr.year,
        fr.month,
        fr.platform_id,
        SUM(fr.total_plays) as plays,
        SUM(fr.revenue_amount) as revenue,
        SUM(fr.royalty_amount) as royalties
    FROM fact_monthly_revenue fr
    JOIN whitelabel.song ws ON fr.song_id = ws.song_id
    JOIN whitelabel.artist wa ON ws.artist_id = wa.artist_id
    JOIN whitelabel.label wl ON ws.label_id = wl.label_id
    WHERE ws.status = 'Released'
    GROUP BY ws.isrc, ws.title, wa.artist_name, wl.label_name, fr.year, fr.month, fr.platform_id
)
SELECT 
    isrc,
    title,
    artist_name,
    label_name,
    year,
    month,
    SUM(plays) as total_plays,
    SUM(revenue) as total_revenue,
    SUM(royalties) as total_royalties,
    COUNT(DISTINCT platform_id) as platform_count,
    ROUND(AVG(revenue / NULLIF(plays, 0)), 6) as avg_revenue_per_play
FROM song_metrics
GROUP BY isrc, title, artist_name, label_name, year, month;
```

### 7.5 Geographic Analytics
```sql
CREATE MATERIALIZED VIEW mv_geographic_performance AS
SELECT 
    g.country_code,
    g.country_name,
    g.region,
    fr.year,
    fr.month,
    COUNT(DISTINCT ws.artist_id) as artist_count,
    COUNT(DISTINCT ws.song_id) as song_count,
    COUNT(DISTINCT ws.label_id) as label_count,
    SUM(fr.total_plays) as total_plays,
    SUM(fr.revenue_amount) as total_revenue,
    SUM(fr.royalty_amount) as total_royalties,
    ROUND(SUM(fr.revenue_amount) / NULLIF(SUM(fr.total_plays), 0), 6) as revenue_per_play,
    ROUND(SUM(fr.royalty_amount) * 100.0 / NULLIF(SUM(fr.revenue_amount), 0), 2) as royalty_percentage
FROM fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN dim_geography g ON fr.geography_id = g.geography_id
WHERE ws.status = 'Released'
GROUP BY g.country_code, g.country_name, g.region, fr.year, fr.month;
```

### 7.6 Cross-Dimensional Analytics
```sql
-- Label Performance by Platform
CREATE MATERIALIZED VIEW mv_label_platform_performance AS
SELECT 
    wl.label_name,
    pc.platform_name,
    fr.year,
    fr.month,
    COUNT(DISTINCT ws.artist_id) as artists,
    COUNT(DISTINCT ws.song_id) as songs,
    SUM(fr.total_plays) as plays,
    SUM(fr.revenue_amount) as revenue,
    SUM(fr.royalty_amount) as royalty,
    ROUND(SUM(fr.revenue_amount) / NULLIF(SUM(fr.total_plays), 0), 6) as revenue_per_play,
    ROUND(SUM(fr.royalty_amount) * 100.0 / NULLIF(SUM(fr.revenue_amount), 0), 2) as royalty_percentage
FROM fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN whitelabel.label wl ON ws.label_id = wl.label_id
JOIN platform_config pc ON fr.platform_id = pc.platform_id
WHERE ws.status = 'Released'
AND pc.is_active = true
GROUP BY wl.label_name, pc.platform_name, fr.year, fr.month;

-- Geographic Distribution by Label
CREATE MATERIALIZED VIEW mv_label_geography_performance AS
SELECT 
    wl.label_name,
    g.region,
    g.country_name,
    fr.year,
    fr.month,
    COUNT(DISTINCT ws.artist_id) as artists,
    COUNT(DISTINCT ws.song_id) as songs,
    SUM(fr.total_plays) as plays,
    SUM(fr.revenue_amount) as revenue,
    SUM(fr.royalty_amount) as royalties,
    ROUND(SUM(fr.revenue_amount) * 100.0 / SUM(SUM(fr.revenue_amount)) OVER (
        PARTITION BY wl.label_name, fr.year, fr.month
    ), 2) as region_share,
    ROUND(SUM(fr.royalty_amount) * 100.0 / NULLIF(SUM(fr.revenue_amount), 0), 2) as royalty_percentage
FROM fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN whitelabel.label wl ON ws.label_id = wl.label_id
JOIN dim_geography g ON fr.geography_id = g.geography_id
WHERE ws.status = 'Released'
GROUP BY wl.label_name, g.region, g.country_name, fr.year, fr.month;

-- Artist Platform Performance by Label
CREATE MATERIALIZED VIEW mv_artist_platform_label AS
SELECT 
    wl.label_name,
    wa.artist_name,
    pc.platform_name,
    fr.year,
    fr.month,
    COUNT(DISTINCT ws.song_id) as songs,
    SUM(fr.total_plays) as plays,
    SUM(fr.revenue_amount) as revenue,
    SUM(fr.royalty_amount) as royalty,
    ROUND(SUM(fr.revenue_amount) / NULLIF(SUM(fr.total_plays), 0), 6) as revenue_per_play,
    ROUND(SUM(fr.royalty_amount) * 100.0 / NULLIF(SUM(fr.revenue_amount), 0), 2) as royalty_percentage
FROM fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN whitelabel.artist wa ON ws.artist_id = wa.artist_id 
JOIN whitelabel.label wl ON ws.label_id = wl.label_id
JOIN platform_config pc ON fr.platform_id = pc.platform_id
WHERE ws.status = 'Released'
AND pc.is_active = true
GROUP BY wl.label_name, wa.artist_name, pc.platform_name, fr.year, fr.month;

-- ISRC Performance by Geography and Platform
CREATE MATERIALIZED VIEW mv_isrc_geo_platform AS
SELECT 
    ws.isrc,
    ws.title,
    wa.artist_name,
    wl.label_name,
    g.region,
    pc.platform_name,
    fr.year,
    fr.month,
    SUM(fr.total_plays) as plays,
    SUM(fr.revenue_amount) as revenue,
    SUM(fr.royalty_amount) as royalties,
    ROUND(SUM(fr.revenue_amount) / NULLIF(SUM(fr.total_plays), 0), 6) as revenue_per_play,
    ROUND(SUM(fr.royalty_amount) * 100.0 / NULLIF(SUM(fr.revenue_amount), 0), 2) as royalty_percentage,
    ROUND(SUM(fr.revenue_amount) * 100.0 / SUM(SUM(fr.revenue_amount)) OVER (
        PARTITION BY ws.isrc, fr.year, fr.month
    ), 2) as platform_share
FROM fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN whitelabel.artist wa ON ws.artist_id = wa.artist_id
JOIN whitelabel.label wl ON ws.label_id = wl.label_id
JOIN dim_geography g ON fr.geography_id = g.geography_id
JOIN platform_config pc ON fr.platform_id = pc.platform_id
WHERE ws.status = 'Released'
AND pc.is_active = true
GROUP BY ws.isrc, ws.title, wa.artist_name, wl.label_name, g.region, pc.platform_name, fr.year, fr.month;
```

### 7.7 Platform Analytics
```sql
CREATE MATERIALIZED VIEW mv_platform_analytics AS
WITH platform_trends AS (
    SELECT 
        pc.platform_name,
        pc.revenue_share_percentage,
        fr.year,
        fr.month,
        COUNT(DISTINCT ws.song_id) as unique_songs,
        COUNT(DISTINCT ws.artist_id) as unique_artists,
        COUNT(DISTINCT ws.label_id) as unique_labels,
        COUNT(DISTINCT ws.isrc) as unique_isrcs,
        SUM(fr.total_plays) as total_plays,
        SUM(fr.revenue_amount) as total_revenue,
        SUM(fr.royalty_amount) as total_royalties,
        MIN(fr.created_at) as earliest_record,
        MAX(fr.created_at) as latest_record
    FROM fact_monthly_revenue fr
    JOIN whitelabel.song ws ON fr.song_id = ws.song_id
    JOIN platform_config pc ON fr.platform_id = pc.platform_id
    WHERE ws.status = 'Released'
    AND pc.is_active = true
    GROUP BY pc.platform_name, pc.revenue_share_percentage, fr.year, fr.month
)
SELECT 
    platform_name,
    revenue_share_percentage,
    year,
    month,
    unique_songs,
    unique_artists,
    unique_labels,
    unique_isrcs,
    total_plays,
    total_revenue,
    total_royalties,
    ROUND(total_royalties * 100.0 / NULLIF(total_revenue, 0), 2) as royalty_percentage,
    ROUND(total_revenue::numeric / NULLIF(total_plays, 0), 6) as revenue_per_play,
    earliest_record,
    latest_record
FROM platform_trends
ORDER BY year DESC, month DESC, total_revenue DESC;
```

## 8. Monitoring and Maintenance

### 8.1 Data Quality Checks
```sql
-- Revenue data monitoring
SELECT 
    fr.year, 
    fr.month,
    COUNT(*) as record_count,
    COUNT(DISTINCT ws.artist_id) as artist_count,
    COUNT(DISTINCT ws.label_id) as label_count,
    COUNT(DISTINCT pc.platform_id) as platform_count,
    SUM(CASE WHEN fr.royalty_amount > fr.revenue_amount THEN 1 ELSE 0 END) as invalid_royalties,
    SUM(CASE WHEN fr.total_plays < 0 THEN 1 ELSE 0 END) as negative_plays,
    ROUND(SUM(fr.royalty_amount) * 100.0 / NULLIF(SUM(fr.revenue_amount), 0), 2) as avg_royalty_rate,
    MIN(fr.created_at) as earliest_record,
    MAX(fr.created_at) as latest_record
FROM fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN platform_config pc ON fr.platform_id = pc.platform_id
WHERE ws.status = 'Released'
GROUP BY fr.year, fr.month
ORDER BY fr.year DESC, fr.month DESC;

-- Missing revenue data check
SELECT 
    ws.isrc,
    ws.title,
    wa.artist_name,
    wl.label_name,
    pc.platform_name,
    COUNT(fr.*) as months_with_data,
    MIN(fr.year || '-' || fr.month) as first_month,
    MAX(fr.year || '-' || fr.month) as last_month,
    ROUND(SUM(fr.royalty_amount) * 100.0 / NULLIF(SUM(fr.revenue_amount), 0), 2) as avg_royalty_rate
FROM whitelabel.song ws
JOIN whitelabel.artist wa ON ws.artist_id = wa.artist_id
JOIN whitelabel.label wl ON ws.label_id = wl.label_id
CROSS JOIN platform_config pc
LEFT JOIN fact_monthly_revenue fr ON ws.song_id = fr.song_id 
    AND fr.platform_id = pc.platform_id
WHERE ws.status = 'Released'
AND pc.is_active = true
GROUP BY ws.isrc, ws.title, wa.artist_name, wl.label_name, pc.platform_name
HAVING COUNT(fr.*) < 3;  -- Less than 3 months of data

-- Platform data consistency
SELECT 
    pc.platform_name,
    fr.year,
    fr.month,
    COUNT(DISTINCT ws.song_id) as songs,
    COUNT(DISTINCT ws.artist_id) as artists,
    COUNT(DISTINCT ws.label_id) as labels,
    SUM(fr.total_plays) as plays,
    SUM(fr.revenue_amount) as revenue,
    ROUND(SUM(fr.royalty_amount) * 100.0 / NULLIF(SUM(fr.revenue_amount), 0), 2) as royalty_rate,
    MIN(fr.created_at) as earliest_record,
    MAX(fr.created_at) as latest_record
FROM platform_config pc
LEFT JOIN fact_monthly_revenue fr ON pc.platform_id = fr.platform_id
LEFT JOIN whitelabel.song ws ON fr.song_id = ws.song_id
WHERE pc.is_active = true
AND ws.status = 'Released'
GROUP BY pc.platform_name, fr.year, fr.month
ORDER BY pc.platform_name, fr.year DESC, fr.month DESC;
```

### 8.2 Performance Monitoring
```sql
-- Table statistics
SELECT 
    schemaname,
    tablename,
    last_vacuum,
    last_analyze,
    n_live_tup as row_count
FROM pg_stat_user_tables
WHERE schemaname = 'analytics'
ORDER BY n_live_tup DESC;

-- Index usage
SELECT 
    schemaname,
    tablename,
    indexrelname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'analytics'
ORDER BY idx_scan DESC;
```

## 9. FastAPI Integration

### 9.1 API Models
```python
# app/models/revenue.py
from pydantic import BaseModel
from typing import List, Optional
from datetime import date, datetime

class RevenueOverview(BaseModel):
    year: int
    month: str
    active_artists: int
    active_labels: int
    active_songs: int
    active_platforms: int
    total_plays: int
    total_revenue: float
    total_royalties: float
    avg_royalty_rate: float
    avg_revenue_per_play: float
    earliest_record: datetime
    latest_record: datetime

class ArtistPerformance(BaseModel):
    artist_id: int
    artist_name: str
    label_id: int
    label_name: str
    songs: int
    platforms: int
    plays: int
    revenue: float
    royalty: float
    royalty_percentage: float
    plays_growth: Optional[float]
    revenue_growth: Optional[float]
    songs_growth: Optional[float]

class PlatformMetrics(BaseModel):
    platform_name: str
    revenue_share_percentage: float
    unique_songs: int
    unique_artists: int
    unique_labels: int
    unique_isrcs: int
    total_plays: int
    total_revenue: float
    total_royalties: float
    royalty_percentage: float
    revenue_per_play: float
    earliest_record: datetime
    latest_record: datetime
```

### 9.2 Database Connection
```python
# app/db/database.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from contextlib import contextmanager

DATABASE_URL = "postgresql://user:password@localhost:5432/royalty_db"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@contextmanager
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

### 9.3 API Endpoints
```python
# app/api/endpoints.py
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from typing import List, Optional, Any
from datetime import date, datetime, timedelta
from pydantic import BaseModel, Field
from slowapi import Limiter
from slowapi.util import get_remote_address
from fastapi_cache import FastAPICache
from fastapi_cache.decorator import cache
from fastapi_cache.backends.redis import RedisBackend
from redis import Redis
from . import models, crud
from .db.database import get_db

# Initialize rate limiter
limiter = Limiter(key_func=get_remote_address)

# Initialize Redis cache
redis = Redis(host='localhost', port=6379, db=0)
FastAPICache.init(RedisBackend(redis), prefix="royalty-cache")

# Cache TTL settings
CACHE_TTL = {
    'revenue_overview': timedelta(minutes=15),
    'artist_performance': timedelta(minutes=5),
    'platform_metrics': timedelta(minutes=10)
}

class ResponseModel(BaseModel):
    success: bool
    message: str = ""
    data: Optional[Any]
    timestamp: datetime = Field(default_factory=datetime.utcnow)

router = APIRouter()

def validate_month(month: str) -> str:
    valid_months = {'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'}
    if month not in valid_months:
        raise HTTPException(status_code=400, detail="Invalid month format")
    return month

def validate_year(year: int) -> int:
    current_year = datetime.now().year
    if not (2020 <= year <= current_year + 1):
        raise HTTPException(status_code=400, detail="Year out of valid range")
    return year

@router.get("/revenue/overview/{year}/{month}", 
    response_model=ResponseModel,
    responses={
        200: {"description": "Revenue overview retrieved successfully"},
        400: {"description": "Invalid year or month format"},
        404: {"description": "No data found for specified period"},
        429: {"description": "Rate limit exceeded"},
        500: {"description": "Internal server error"}
    })
@limiter.limit("60/minute")
@cache(expire=CACHE_TTL['revenue_overview'])
def get_revenue_overview(
    request: Request,
    year: int = Path(..., description="Year (YYYY)", example=2025),
    month: str = Path(..., description="Month (Jan-Dec)", example="Jan"),
    db: Session = Depends(get_db)
):
    """
    Get revenue overview for specified month
    Example: /revenue/overview/2025/Jan
    """
    try:
        year = validate_year(year)
        month = validate_month(month)
        
        data = crud.get_revenue_overview(db, year, month)
        if not data:
            return ResponseModel(success=False, message="No data found for specified period")
        return ResponseModel(success=True, message="Revenue overview retrieved successfully", data=data)
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def validate_artist_id(artist_id: int) -> int:
    if artist_id <= 0:
        raise HTTPException(status_code=400, detail="Invalid artist ID")
    return artist_id

@router.get("/artist/{artist_id}/performance", 
    response_model=ResponseModel,
    responses={
        200: {"description": "Artist performance data retrieved successfully"},
        400: {"description": "Invalid artist ID format"},
        404: {"description": "Artist not found or no performance data available"},
        500: {"description": "Internal server error"}
    })
def get_artist_performance(
    artist_id: int = Path(..., description="Artist ID", example=1, gt=0),
    db: Session = Depends(get_db)
):
    """
    Get artist performance metrics
    Example: /artist/1/performance
    
    Parameters:
    - artist_id: Unique identifier for the artist (must be positive integer)
    """
    try:
        artist_id = validate_artist_id(artist_id)
        
        data = crud.get_artist_performance(db, artist_id)
        if not data:
            return ResponseModel(success=False, message="No data found for specified artist")
        return ResponseModel(success=True, message="Artist performance data retrieved successfully", data=data)
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/platform/metrics", 
    response_model=ResponseModel,
    responses={
        200: {"description": "Platform metrics retrieved successfully"},
        404: {"description": "No platform metrics available"},
        500: {"description": "Internal server error"}
    })
def get_platform_metrics(db: Session = Depends(get_db)):
    """
    Get performance metrics for all platforms
    Example: /platform/metrics
    """
    try:
        data = crud.get_platform_metrics(db)
        if not data:
            return ResponseModel(success=False, message="No platform metrics available")
        return ResponseModel(success=True, data=data)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

### 9.4 Database Queries
```python
# app/crud/queries.py
from sqlalchemy import text

def get_revenue_overview_query(year: int, month: str):
    return text("""
        SELECT * FROM mv_revenue_overview
        WHERE year = :year AND month = :month
    """)

def get_artist_performance_query(artist_id: int):
    return text("""
        SELECT * FROM mv_artist_dashboard
        WHERE artist_id = :artist_id
        ORDER BY year DESC, month DESC
        LIMIT 1
    """)

def get_platform_metrics_query():
    return text("""
        SELECT 
            platform_name,
            revenue_share_percentage,
            unique_songs,
            unique_artists,
            unique_labels,
            unique_isrcs,
            total_plays,
            total_revenue,
            total_royalties,
            royalty_percentage,
            revenue_per_play,
            earliest_record,
            latest_record
        FROM mv_platform_analytics
        WHERE (year, month) = (
            SELECT year, month 
            FROM mv_platform_analytics
            ORDER BY year DESC, month DESC 
            LIMIT 1
        )
        ORDER BY total_revenue DESC
    """)
```

### 9.5 Example Usage

#### Revenue Overview
```python
# Example request
import requests

response = requests.get("http://localhost:8000/revenue/overview/2025/Jan")
data = response.json()
print(data)

# Example output
{
    "success": true,
    "message": "Revenue overview retrieved successfully",
    "data": {
        "year": 2025,
        "month": "Jan",
        "active_artists": 2,
        "active_labels": 2,
        "active_songs": 3,
        "active_platforms": 2,
        "total_plays": 33000,
        "total_revenue": 1650.00,
        "total_royalties": 897.75,
        "avg_royalty_rate": 54.41,
        "avg_revenue_per_play": 0.050000,
        "earliest_record": "2025-01-01T00:00:00",
        "latest_record": "2025-01-31T23:59:59"
    },
    "timestamp": "2025-01-01T00:00:01Z"
}
```

#### Artist Performance
```python
# Example request
response = requests.get("http://localhost:8000/artist/1/performance")
data = response.json()
print(data)

# Example output
{
    "success": true,
    "message": "Artist performance data retrieved successfully",
    "data": {
        "artist_id": 1,
        "artist_name": "John Smith",
        "label_id": 1,
        "label_name": "Sony Music",
        "songs": 2,
        "platforms": 2,
        "plays": 18000,
        "revenue": 900.00,
        "royalty": 504.00,
        "royalty_percentage": 56.00,
        "plays_growth": 15.20,
        "revenue_growth": 12.50,
        "songs_growth": 0.00
    },
    "timestamp": "2025-01-01T00:00:01Z"
}
```

#### Platform Metrics
```python
# Example request
response = requests.get("http://localhost:8000/platform/metrics")
data = response.json()
print(data)

# Example output
{
    "success": true,
    "message": "Platform metrics retrieved successfully",
    "data": [
        {
            "platform_name": "Spotify",
            "revenue_share_percentage": 70.00,
            "unique_songs": 2,
            "unique_artists": 2,
            "unique_labels": 2,
            "unique_isrcs": 2,
            "total_plays": 25000,
            "total_revenue": 1250.00,
            "total_royalties": 875.00,
            "royalty_percentage": 70.00,
            "revenue_per_play": 0.050000,
            "earliest_record": "2025-01-01T00:00:00",
            "latest_record": "2025-01-31T23:59:59"
        },
        {
            "platform_name": "Apple Music",
            "revenue_share_percentage": 70.00,
            "unique_songs": 1,
            "unique_artists": 1,
            "unique_labels": 1,
            "unique_isrcs": 1,
            "total_plays": 8000,
            "total_revenue": 400.00,
            "total_royalties": 280.00,
            "royalty_percentage": 70.00,
            "revenue_per_play": 0.050000,
            "earliest_record": "2025-01-01T00:00:00",
            "latest_record": "2025-01-31T23:59:59"
        }
    ],
    "timestamp": "2025-01-01T00:00:01Z"
}
```

These endpoints provide the necessary data for building dashboards with:
- Revenue overviews
- Artist performance metrics
- Platform analytics
- Growth tracking

The responses are structured for easy integration with frontend visualization libraries.
