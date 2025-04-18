-- Drop and recreate both schemas
DROP SCHEMA IF EXISTS whitelabel CASCADE;
DROP SCHEMA IF EXISTS analytics CASCADE;

-- Create whitelabel schema
CREATE SCHEMA whitelabel;

-- Create whitelabel tables
CREATE TABLE whitelabel.label (
    label_id SERIAL PRIMARY KEY,
    label_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE whitelabel.artist (
    artist_id INT PRIMARY KEY,  -- This will match the userid from RevenueSheet
    artist_name VARCHAR(255) NOT NULL,
    payment_threshold DECIMAL(15,6) DEFAULT 100.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE whitelabel.song (
    song_id SERIAL PRIMARY KEY,
    isrc VARCHAR(12) NOT NULL,
    title VARCHAR(255) NOT NULL,
    artist_id INT NOT NULL REFERENCES whitelabel.artist(artist_id),
    label_id INT NOT NULL REFERENCES whitelabel.label(label_id),
    status VARCHAR(20) DEFAULT 'Released' CHECK (status IN ('Released', 'Draft', 'Archived')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_isrc UNIQUE (isrc)
);

-- Drop and recreate analytics schema
DROP SCHEMA IF EXISTS analytics CASCADE;

CREATE SCHEMA analytics;

-- Recreate tables as per new design
CREATE TABLE analytics.dim_geography (
    geography_id SERIAL PRIMARY KEY,
    country_code CHAR(2) NOT NULL,
    country_name VARCHAR(100) NOT NULL,
    region VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_country UNIQUE (country_code)
);

CREATE TABLE analytics.platform_config (
    platform_id SERIAL PRIMARY KEY,
    platform_name VARCHAR(100) NOT NULL,
    revenue_share_percentage DECIMAL(5,2) NOT NULL,
    effective_from DATE NOT NULL,
    effective_to DATE,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT valid_share CHECK (revenue_share_percentage BETWEEN 0 AND 100)
);

CREATE TABLE analytics.fact_monthly_revenue (
    revenue_id BIGSERIAL PRIMARY KEY,
    year INT NOT NULL,
    month VARCHAR(3) NOT NULL,
    song_id INT NOT NULL REFERENCES whitelabel.song(song_id),
    platform_id INT NOT NULL REFERENCES analytics.platform_config(platform_id),
    geography_id INT REFERENCES analytics.dim_geography(geography_id),
    artist_id INT NOT NULL REFERENCES whitelabel.artist(artist_id),
    total_plays INT NOT NULL,
    revenue_amount DECIMAL(15,6) NOT NULL,
    royalty_amount DECIMAL(15,6) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_amounts CHECK (royalty_amount <= revenue_amount),
    CONSTRAINT valid_month CHECK (month IN ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                                          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'))
);

-- Clear staging table on create
DROP TABLE IF EXISTS analytics.stg_revenue_import;

CREATE TABLE analytics.stg_revenue_import (
    id TEXT PRIMARY KEY,  -- Will store the CSV's UUID
    service VARCHAR(100) NOT NULL,
    month DATE NOT NULL,
    isrc VARCHAR(12) NOT NULL,
    product VARCHAR(255),
    song_name VARCHAR(255) NOT NULL,
    artist VARCHAR(255) NOT NULL,
    album VARCHAR(255),
    label VARCHAR(255) NOT NULL,
    file_name VARCHAR(255),
    country CHAR(2) NOT NULL,
    total DECIMAL(15,6) NOT NULL,
    royalty DECIMAL(15,6) NOT NULL,
    userid INT NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING',
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Add a check constraint for positive amounts
    CONSTRAINT positive_amounts CHECK (total >= 0 AND royalty >= 0)
);

-- Add index to help with duplicate detection
CREATE INDEX idx_stg_revenue_import_natural_key 
ON analytics.stg_revenue_import (month, isrc, country, service);

-- Insert labels from datauuid.csv
INSERT INTO whitelabel.label (label_name) VALUES
('Abhi'),
('Abhishek Sikheda Official'),
('Akay Dhariwal'),
('Alap Audios Entertainment'),
('Aman Digital'),
('Andy Roopgarhiye'),
('Ankit Gujjar Sadullapur'),
('Ankit X Sawan Team'),
('Bhakti Mala'),
('Chaudhary Rajdeep official'),
('Dc Sharma Salempuriya'),
('Desi feel'),
('Dhakad Records'),
('DT In Mood'),
('F O Amit Pandit'),
('Harry Dhaliwal Music'),
('HighHill Records'),
('HR Stuff Music'),
('INK Records'),
('Iomupadhyay'),
('Jatin Saroha'),
('Jems Entertainments'),
('Kartik Soni Productions'),
('Link Music Haryanvi'),
('Mantora Wala Official'),
('Matnora Wala Official'),
('Mavi Haryana'),
('MG Gujjar'),
('Miki Malang');

-- Insert artists from datauuid.csv
INSERT INTO whitelabel.artist (artist_id, artist_name) VALUES
(48, 'Amrit Nagra'),
(28, 'Abhishek Sikheda'),
(105, 'Akay Dhariwal'),
(40, 'Sukhjinder Alfaaz'),
(37, 'Ruhi Behal'),
(77, 'Manjeet Ridhal'),
(63, 'Harendra Nagar'),
(78, 'Raju Haryanvi'),
(79, 'Vishnu Namunda'),
(34, 'Jonga'),
(39, 'Chaudhary Rajdeep'),
(43, 'U.K. Haryanvi'),
(17, 'A Jay'),
(67, 'Miki Malang'),
(18, 'Meet Amit'),
(114, 'Sahil Nidawli'),
(103, 'Jatin Saroha'),
(70, 'Rahul Puthi'),
(10, 'Kartik Soni'),
(96, 'Amit Pandit'),
(45, 'Christ'),
(36, 'Kaaj'),
(108, 'M.G. Gujjar'),
(59, 'Sandeep Matnora');

-- Insert existing songs
INSERT INTO whitelabel.song (isrc, title, artist_id, label_id) VALUES
('INK782201237', 'Cloud 9', 48, 1),
('INK782200406', 'Naam Ka Bawaal (Barood Se Itna 2)', 28, 2),
('INK782201638', 'Wajah', 105, 3),
('INK782200451', 'Pyar Alfaaz', 40, 4),
('INK782200460', 'Jaat', 39, 5),
('INK782201008', 'Gebi Shab Teri Aarti Gau', 77, 6),
('INK782200790', 'Swarg Ki Hoor', 63, 7),
('INK782201024', 'Mera Ala Baman', 78, 8),
('INK782201146', 'Lori Sunaye Gora Maiya', 63, 9),
('INK782201654', 'Takdeer', 59, 26),
('TCAGF2234045', 'Sooraj', 67, 29),
('TCAFY2105869', 'Bhyani Te Hisar', 67, 29),
('TCAFT2137100', 'Bhand', 67, 29);

-- Insert additional songs
INSERT INTO whitelabel.song (isrc, title, artist_id, label_id) VALUES
('INK782201202', 'Chora Baman Ka', 79, 8),
('INK782201397', 'Titli', 39, 5),
('INK782200746', 'Kali Car', 36, 27),
('INK782201647', 'Gujjar Baaghi', 108, 28),
('INK782201678', 'Kaam Bhaari', 105, 3),
('INK782200542', 'Badmashi Ka Trend', 28, 2),
('INK782200738', 'Matlab Ka Sansar', 59, 26),
('INK782200272', 'Teri Meri Jodi', 34, 24),
('INK782201080', 'Gujjar Ka Yudh', 63, 7),
('INK782200488', 'Jo Din Aave So Din Jaahi', 40, 4),
('INK782200707', 'Barood Se itna 2 (Lofi Mix)', 28, 2),
('INK782200046', 'Meerut Ke Yaar', 28, 2),
('INK782201250', 'Baman Ki Barat', 78, 8),
('INK782201065', 'Gebi Shab roopgarh aala', 77, 6),
('INK782201637', 'Badnaam', 105, 3),
('INK782200441', 'Barood Se itna 2 Dj Remix', 28, 2),
('INK782201600', 'Gundagardi', 34, 24),
('INK782200425', 'Channa', 37, 4),
('INK782201229', 'Jai Jai Parshuram', 79, 8),
('INK782300114', 'Dekh Aakhbaar', 63, 26),
('INK782201272', 'Na Karo Ignore', 78, 8),
('INK782201365', 'Pyar Ho Gaya', 37, 4),
('INK782300176', 'Hukum Ka Ikka', 59, 26),
('INK782201102', 'Brahman Brand', 78, 8),
('INK782201186', 'Rajput Kaum', 78, 8),
('INK782201641', 'Dalli', 105, 3),
('INK782300130', 'Gurjar ka Sikka', 108, 28),
('INK782200261', 'Barood Se Itna 2 OG', 28, 2);

-- Insert platform configuration
INSERT INTO analytics.platform_config (
    platform_name, 
    revenue_share_percentage, 
    effective_from,
    is_active
) VALUES
('Apple', 70.00, '2023-01-01', true);

-- Insert geography dimension data
INSERT INTO analytics.dim_geography (country_code, country_name, region) VALUES
('AU', 'Australia', 'Oceania'),
('CA', 'Canada', 'North America'),
('GB', 'United Kingdom', 'Europe'),
('IN', 'India', 'Asia'),
('US', 'United States', 'North America'),
('NZ', 'New Zealand', 'Oceania'),
('SG', 'Singapore', 'Asia'),
('JP', 'Japan', 'Asia'),
('DE', 'Germany', 'Europe'),
('FR', 'France', 'Europe');

-- Create materialized views
CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.mv_revenue_overview AS
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
FROM analytics.fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN analytics.platform_config pc ON fr.platform_id = pc.platform_id
WHERE ws.status = 'Released'
AND pc.is_active = true
GROUP BY fr.year, fr.month;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_revenue_overview_unique 
ON analytics.mv_revenue_overview(year, month);

CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.mv_artist_dashboard AS
SELECT 
    fr.revenue_id,
    ws.artist_id,
    wa.artist_name,
    wl.label_id,
    wl.label_name,
    fr.year,
    fr.month,
    ws.isrc,
    pc.platform_name as service,
    fr.total_plays as plays,
    fr.revenue_amount as revenue,
    fr.royalty_amount as royalty,
    ROUND(fr.royalty_amount * 100.0 / NULLIF(fr.revenue_amount, 0), 2) as royalty_percentage
FROM analytics.fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN whitelabel.artist wa ON ws.artist_id = wa.artist_id
JOIN whitelabel.label wl ON ws.label_id = wl.label_id
JOIN analytics.platform_config pc ON fr.platform_id = pc.platform_id
WHERE ws.status = 'Released';

-- Primary key is now just the fact_monthly_revenue ID since each record is unique
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_artist_dashboard_unique 
ON analytics.mv_artist_dashboard(revenue_id);

CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.mv_platform_analytics AS
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
FROM analytics.fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN analytics.platform_config pc ON fr.platform_id = pc.platform_id
WHERE ws.status = 'Released'
AND pc.is_active = true
GROUP BY pc.platform_name, pc.revenue_share_percentage, fr.year, fr.month;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_platform_analytics_unique 
ON analytics.mv_platform_analytics(platform_name, year, month);

-- Artist Earnings View (Monthly earnings by artist)
CREATE MATERIALIZED VIEW analytics.mv_artist_earnings AS
SELECT 
    fr.year,
    fr.month,
    ws.artist_id,
    wa.artist_name,
    SUM(fr.total_plays) as total_plays,
    SUM(fr.revenue_amount) as total_revenue,
    SUM(fr.royalty_amount) as total_royalties,
    ROUND(AVG(fr.royalty_amount * 100.0 / NULLIF(fr.revenue_amount, 0)), 2) as avg_royalty_percentage,
    COUNT(DISTINCT ws.song_id) as unique_songs,
    COUNT(DISTINCT pc.platform_id) as platform_count
FROM analytics.fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN whitelabel.artist wa ON ws.artist_id = wa.artist_id
JOIN analytics.platform_config pc ON fr.platform_id = pc.platform_id
WHERE ws.status = 'Released'
GROUP BY fr.year, fr.month, ws.artist_id, wa.artist_name;

CREATE UNIQUE INDEX idx_mv_artist_earnings_unique 
ON analytics.mv_artist_earnings(year, month, artist_id);

-- Platform Revenue View (Revenue breakdown by platform)
CREATE MATERIALIZED VIEW analytics.mv_platform_revenue AS
SELECT 
    fr.year,
    fr.month,
    pc.platform_name,
    pc.revenue_share_percentage,
    COUNT(DISTINCT fr.song_id) as songs_played,
    COUNT(DISTINCT ws.artist_id) as unique_artists,
    SUM(fr.total_plays) as total_plays,
    SUM(fr.revenue_amount) as total_revenue,
    SUM(fr.royalty_amount) as total_royalties
FROM analytics.fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN analytics.platform_config pc ON fr.platform_id = pc.platform_id
WHERE ws.status = 'Released'
GROUP BY fr.year, fr.month, pc.platform_name, pc.revenue_share_percentage;

CREATE UNIQUE INDEX idx_mv_platform_revenue_unique 
ON analytics.mv_platform_revenue(year, month, platform_name);

-- Artist Performance View (Song performance by artist)
CREATE MATERIALIZED VIEW analytics.mv_artist_performance AS
SELECT 
    fr.year,
    fr.month,
    ws.artist_id,
    wa.artist_name,
    ws.song_id,
    ws.title as song_name,
    ws.isrc,
    SUM(fr.total_plays) as total_plays,
    SUM(fr.revenue_amount) as total_revenue,
    SUM(fr.royalty_amount) as total_royalties,
    COUNT(DISTINCT pc.platform_id) as platform_count
FROM analytics.fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN whitelabel.artist wa ON ws.artist_id = wa.artist_id
JOIN analytics.platform_config pc ON fr.platform_id = pc.platform_id
WHERE ws.status = 'Released'
GROUP BY fr.year, fr.month, ws.artist_id, wa.artist_name, ws.song_id, ws.title, ws.isrc;

CREATE UNIQUE INDEX idx_mv_artist_performance_unique 
ON analytics.mv_artist_performance(year, month, song_id);

-- Label Performance View (Revenue by label)
CREATE MATERIALIZED VIEW analytics.mv_label_performance AS
SELECT 
    fr.year,
    fr.month,
    wl.label_id,
    wl.label_name,
    COUNT(DISTINCT ws.artist_id) as unique_artists,
    COUNT(DISTINCT ws.song_id) as unique_songs,
    SUM(fr.total_plays) as total_plays,
    SUM(fr.revenue_amount) as total_revenue,
    SUM(fr.royalty_amount) as total_royalties
FROM analytics.fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN whitelabel.label wl ON ws.label_id = wl.label_id
WHERE ws.status = 'Released'
GROUP BY fr.year, fr.month, wl.label_id, wl.label_name;

CREATE UNIQUE INDEX idx_mv_label_performance_unique 
ON analytics.mv_label_performance(year, month, label_id);

-- Artist Platform Label Matrix (Cross-analysis)
CREATE MATERIALIZED VIEW analytics.mv_artist_platform_label AS
SELECT 
    fr.year,
    fr.month,
    wa.artist_id,
    wa.artist_name,
    pc.platform_name,
    wl.label_name,
    COUNT(DISTINCT ws.song_id) as unique_songs,
    SUM(fr.total_plays) as total_plays,
    SUM(fr.revenue_amount) as total_revenue,
    SUM(fr.royalty_amount) as total_royalties
FROM analytics.fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN whitelabel.artist wa ON ws.artist_id = wa.artist_id
JOIN whitelabel.label wl ON ws.label_id = wl.label_id
JOIN analytics.platform_config pc ON fr.platform_id = pc.platform_id
WHERE ws.status = 'Released'
GROUP BY fr.year, fr.month, wa.artist_id, wa.artist_name, pc.platform_name, wl.label_name;

CREATE UNIQUE INDEX idx_mv_artist_platform_label_unique 
ON analytics.mv_artist_platform_label(year, month, artist_id, platform_name, label_name);

-- Geographic Analysis View
CREATE MATERIALIZED VIEW analytics.mv_isrc_geo_platform AS
SELECT 
    fr.year,
    fr.month,
    ws.isrc,
    ws.title as song_name,
    wa.artist_name,
    dg.country_code,
    dg.region,
    pc.platform_name,
    SUM(fr.total_plays) as total_plays,
    SUM(fr.revenue_amount) as total_revenue,
    SUM(fr.royalty_amount) as total_royalties
FROM analytics.fact_monthly_revenue fr
JOIN whitelabel.song ws ON fr.song_id = ws.song_id
JOIN whitelabel.artist wa ON ws.artist_id = wa.artist_id
JOIN analytics.dim_geography dg ON fr.geography_id = dg.geography_id
JOIN analytics.platform_config pc ON fr.platform_id = pc.platform_id
WHERE ws.status = 'Released'
GROUP BY fr.year, fr.month, ws.isrc, ws.title, wa.artist_name, dg.country_code, dg.region, pc.platform_name;

CREATE UNIQUE INDEX idx_mv_isrc_geo_platform_unique 
ON analytics.mv_isrc_geo_platform(year, month, isrc, country_code, platform_name);

-- Create ETL stored procedure
CREATE OR REPLACE PROCEDURE analytics.process_revenue_import()
LANGUAGE plpgsql AS $$
DECLARE
    processed_ids TEXT[];
    existing_record RECORD;
BEGIN
    -- Mark duplicates as 'SKIPPED'
    UPDATE analytics.stg_revenue_import staging
    SET status = 'SKIPPED',
        error_message = 'Record already exists for this month/isrc/country/service'
    WHERE status = 'PENDING'
    AND EXISTS (
        SELECT 1 
        FROM analytics.fact_monthly_revenue fact
        JOIN whitelabel.song songs ON fact.song_id = songs.song_id
        JOIN analytics.platform_config platform ON fact.platform_id = platform.platform_id
        WHERE songs.isrc = staging.isrc 
        AND EXTRACT(YEAR FROM staging.month)::int = fact.year
        AND TO_CHAR(staging.month, 'Mon') = fact.month
        AND platform.platform_name = staging.service
    );

        -- Transform and load non-duplicate records
    WITH staging_data AS (
        SELECT s.id, s.month, s.isrc, s.service, s.userid, s.total, s.royalty,
               songs.song_id, platform.platform_id, platform.revenue_share_percentage,
               geo.geography_id
        FROM analytics.stg_revenue_import s
        JOIN whitelabel.song songs ON s.isrc = songs.isrc
        JOIN analytics.platform_config platform ON s.service = platform.platform_name
            AND s.month >= platform.effective_from
            AND (platform.effective_to IS NULL OR s.month <= platform.effective_to)
        LEFT JOIN analytics.dim_geography geo ON s.country = geo.country_code
        WHERE s.status = 'PENDING'
        AND songs.status = 'Released'
        AND platform.is_active = true
    ),
    inserted_records AS (
        INSERT INTO analytics.fact_monthly_revenue (
            year, month, song_id, platform_id, artist_id,
            total_plays, revenue_amount, royalty_amount, geography_id
        )
        SELECT 
            EXTRACT(YEAR FROM month)::int as year,
            TO_CHAR(month, 'Mon') as month,
            song_id,
            platform_id,
            userid as artist_id,
            total::int as total_plays,
            (royalty * 100.0 / revenue_share_percentage) as revenue_amount,
            royalty as royalty_amount,
            geography_id
        FROM staging_data
        RETURNING 1
    )
    SELECT array_agg(id) INTO processed_ids FROM staging_data;
    
    -- Mark processed records if any were processed
    IF processed_ids IS NOT NULL THEN
        UPDATE analytics.stg_revenue_import 
        SET status = 'PROCESSED'
        WHERE id = ANY(processed_ids);
    END IF;

    -- Mark remaining pending records as failed
    UPDATE analytics.stg_revenue_import 
    SET status = 'FAILED',
        error_message = CASE
            WHEN NOT EXISTS (
                SELECT 1 FROM whitelabel.song songs 
                WHERE songs.isrc = stg_revenue_import.isrc
            ) THEN 'Invalid ISRC'
            WHEN NOT EXISTS (
                SELECT 1 FROM analytics.platform_config platform 
                WHERE platform.platform_name = stg_revenue_import.service
                AND platform.is_active = true
            ) THEN 'Invalid platform'
            WHEN NOT EXISTS (
                SELECT 1 FROM whitelabel.artist artist 
                WHERE artist.artist_id = stg_revenue_import.userid
            ) THEN 'Invalid artist ID'
            ELSE 'Song not released'
        END
    WHERE status = 'PENDING';

    -- Refresh materialized views only if we processed any records
    IF processed_ids IS NOT NULL THEN
        -- Core views (required)
        REFRESH MATERIALIZED VIEW analytics.mv_revenue_overview;
        REFRESH MATERIALIZED VIEW analytics.mv_artist_dashboard;
        REFRESH MATERIALIZED VIEW analytics.mv_platform_analytics;

        -- Additional analytics views
        REFRESH MATERIALIZED VIEW analytics.mv_artist_earnings;
        REFRESH MATERIALIZED VIEW analytics.mv_platform_revenue;
        REFRESH MATERIALIZED VIEW analytics.mv_artist_performance;
        REFRESH MATERIALIZED VIEW analytics.mv_label_performance;
        REFRESH MATERIALIZED VIEW analytics.mv_artist_platform_label;
        REFRESH MATERIALIZED VIEW analytics.mv_isrc_geo_platform;
    END IF;
END;
$$;
