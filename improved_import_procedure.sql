CREATE OR REPLACE PROCEDURE analytics.process_revenue_import()
LANGUAGE plpgsql AS $$
BEGIN
    -- Transform and load revenue data
    WITH song_details AS (
        SELECT 
            s.id as staging_id,
            ws.song_id,
            s.artist_id,
            pc.platform_id,
            EXTRACT(YEAR FROM TO_DATE(s.month_year, 'YYYY-MM')) as year,
            TO_CHAR(TO_DATE(s.month_year, 'YYYY-MM'), 'Mon') as month,
            s.plays,
            s.revenue,
            s.revenue * (pc.revenue_share_percentage/100.0) as royalty
        FROM analytics.stg_revenue_import s
        JOIN whitelabel.song ws ON s.isrc = ws.isrc
        JOIN analytics.platform_config pc ON s.platform = pc.platform_name
            AND TO_DATE(s.month_year, 'YYYY-MM') >= pc.effective_from
            AND (pc.effective_to IS NULL OR TO_DATE(s.month_year, 'YYYY-MM') <= pc.effective_to)
        WHERE s.status = 'PENDING'
        AND ws.status = 'Released'
        AND pc.is_active = true
        AND EXISTS (
            SELECT 1 FROM whitelabel.artist a 
            WHERE a.artist_id = s.artist_id
        )
    )
    INSERT INTO analytics.fact_monthly_revenue (
        year, month, song_id, platform_id, artist_id,
        total_plays, revenue_amount, royalty_amount
    )
    SELECT 
        year,
        month,
        song_id,
        platform_id,
        artist_id,
        plays,
        revenue,
        royalty
    FROM song_details
    ON CONFLICT (year, month, song_id, platform_id) DO UPDATE 
    SET 
        total_plays = EXCLUDED.total_plays,
        revenue_amount = EXCLUDED.revenue_amount,
        royalty_amount = EXCLUDED.royalty_amount;
    
    -- Mark processed records
    UPDATE analytics.stg_revenue_import 
    SET status = 'PROCESSED'
    WHERE status = 'PENDING'
    AND EXISTS (
        SELECT 1 
        FROM whitelabel.song ws 
        JOIN analytics.platform_config pc ON stg_revenue_import.platform = pc.platform_name
        WHERE ws.isrc = stg_revenue_import.isrc
        AND ws.status = 'Released'
        AND pc.is_active = true
    )
    AND EXISTS (
        SELECT 1 
        FROM whitelabel.artist a 
        WHERE a.artist_id = stg_revenue_import.artist_id
    );

    -- Mark failed records
    UPDATE analytics.stg_revenue_import 
    SET status = 'FAILED',
        error_message = CASE
            WHEN NOT EXISTS (
                SELECT 1 FROM whitelabel.song ws 
                WHERE ws.isrc = stg_revenue_import.isrc
            ) THEN 'Invalid ISRC'
            WHEN NOT EXISTS (
                SELECT 1 FROM analytics.platform_config pc 
                WHERE pc.platform_name = stg_revenue_import.platform
                AND pc.is_active = true
            ) THEN 'Invalid platform'
            WHEN NOT EXISTS (
                SELECT 1 FROM whitelabel.artist a 
                WHERE a.artist_id = stg_revenue_import.artist_id
            ) THEN 'Invalid artist ID'
            ELSE 'Song not released'
        END
    WHERE status = 'PENDING';

    -- Drop and recreate materialized views to handle aggregation properly
    DROP MATERIALIZED VIEW IF EXISTS analytics.mv_revenue_overview;
    DROP MATERIALIZED VIEW IF EXISTS analytics.mv_artist_dashboard;
    DROP MATERIALIZED VIEW IF EXISTS analytics.mv_platform_analytics;

    -- Recreate revenue overview
    CREATE MATERIALIZED VIEW analytics.mv_revenue_overview AS
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
        ROUND(SUM(fr.royalty_amount) * 100.0 / NULLIF(SUM(fr.revenue_amount), 0), 2) as avg_royalty_rate
    FROM analytics.fact_monthly_revenue fr
    JOIN whitelabel.song ws ON fr.song_id = ws.song_id
    JOIN analytics.platform_config pc ON fr.platform_id = pc.platform_id
    WHERE ws.status = 'Released'
    AND pc.is_active = true
    GROUP BY fr.year, fr.month;

    -- Recreate artist dashboard with proper aggregation
    CREATE MATERIALIZED VIEW analytics.mv_artist_dashboard AS
    SELECT 
        a.artist_id,
        a.artist_name,
        fr.year,
        fr.month,
        COUNT(DISTINCT ws.song_id) as songs,
        COUNT(DISTINCT fr.platform_id) as platforms,
        SUM(fr.total_plays) as plays,
        SUM(fr.revenue_amount) as revenue,
        SUM(fr.royalty_amount) as royalty
    FROM whitelabel.artist a
    JOIN analytics.fact_monthly_revenue fr ON a.artist_id = fr.artist_id
    JOIN whitelabel.song ws ON fr.song_id = ws.song_id
    WHERE ws.status = 'Released'
    GROUP BY a.artist_id, a.artist_name, fr.year, fr.month;

    -- Create unique index for the view
    CREATE UNIQUE INDEX ON analytics.mv_artist_dashboard(artist_id, year, month);

END;
$$;

-- Add unique constraint to fact table if not exists
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fact_monthly_revenue_unique_key'
    ) THEN
        ALTER TABLE analytics.fact_monthly_revenue 
        ADD CONSTRAINT fact_monthly_revenue_unique_key 
        UNIQUE (year, month, song_id, platform_id);
    END IF;
END $$;
