-- Ensure we have all countries in dimension table
INSERT INTO analytics.dim_geography (country_code, country_name)
SELECT DISTINCT 
    t.country_code,
    CASE 
        WHEN t.country_code = 'US' THEN 'United States'
        WHEN t.country_code = 'CA' THEN 'Canada'
        WHEN t.country_code = 'GB' THEN 'United Kingdom'
        WHEN t.country_code = 'AU' THEN 'Australia'
        WHEN t.country_code = 'IN' THEN 'India'
        WHEN t.country_code = 'DE' THEN 'Germany'
        WHEN t.country_code = 'FR' THEN 'France'
        WHEN t.country_code = 'JP' THEN 'Japan'
        WHEN t.country_code = 'NZ' THEN 'New Zealand'
        WHEN t.country_code = 'SG' THEN 'Singapore'
        WHEN t.country_code = 'ES' THEN 'Spain'
        WHEN t.country_code = 'CH' THEN 'Switzerland'
        WHEN t.country_code = 'FI' THEN 'Finland'
        WHEN t.country_code = 'IE' THEN 'Ireland'
        WHEN t.country_code = 'PT' THEN 'Portugal'
        WHEN t.country_code = 'MX' THEN 'Mexico'
        WHEN t.country_code = 'UA' THEN 'Ukraine'
        WHEN t.country_code = 'MU' THEN 'Mauritius'
        WHEN t.country_code = 'HU' THEN 'Hungary'
        WHEN t.country_code = 'ZA' THEN 'South Africa'
        WHEN t.country_code = 'AE' THEN 'United Arab Emirates'
        ELSE 'Unknown'
    END as country_name
FROM (
    SELECT DISTINCT unnest(array['US','CA','GB','AU','IN','DE','FR','JP','NZ','SG','ES','CH','FI','IE','PT','MX','UA','MU','HU','ZA','AE']) as country_code
) t
WHERE NOT EXISTS (
    SELECT 1 FROM analytics.dim_geography g 
    WHERE g.country_code = t.country_code
)
ON CONFLICT (country_code) DO NOTHING;

-- Add geography_id to fact table if not exists
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'analytics' 
        AND table_name = 'fact_monthly_revenue'
        AND column_name = 'geography_id'
    ) THEN
        -- Drop old unique constraint if exists
        ALTER TABLE analytics.fact_monthly_revenue 
        DROP CONSTRAINT IF EXISTS fact_monthly_revenue_unique_key;

        -- Add geography_id column
        ALTER TABLE analytics.fact_monthly_revenue 
        ADD COLUMN geography_id integer REFERENCES analytics.dim_geography(geography_id);

        -- Create new unique constraint including geography
        ALTER TABLE analytics.fact_monthly_revenue 
        ADD CONSTRAINT fact_monthly_revenue_unique_key 
        UNIQUE (year, month, song_id, platform_id, geography_id);
    END IF;
END $$;
