-- Function to synchronize data from revenue sheet
CREATE OR REPLACE FUNCTION sync_revenue_data() RETURNS void AS $$
BEGIN
    -- Insert missing artists
    WITH csv_data AS (
        SELECT 
            (regexp_split_to_array(line, ','))[12] as userid,
            (regexp_split_to_array(line, ','))[6] as artist_name
        FROM (
            SELECT unnest(string_to_array(pg_read_file('/home/nitish/Documents/Personal/LabelLift/DesignForRoyalty/RevenueSheet.txt'), E'\n')) AS line
        ) t
        WHERE line NOT LIKE 'service%'
    )
    INSERT INTO whitelabel.artist (artist_id, artist_name, payment_threshold)
    SELECT DISTINCT
        userid::integer,
        artist_name,
        100.00
    FROM csv_data
    WHERE userid::integer NOT IN (SELECT artist_id FROM whitelabel.artist)
    ON CONFLICT (artist_id) DO NOTHING;

    -- Insert missing songs
    WITH csv_data AS (
        SELECT 
            (regexp_split_to_array(line, ','))[3] as isrc,
            (regexp_split_to_array(line, ','))[5] as song_name,
            (regexp_split_to_array(line, ','))[12] as userid,
            (regexp_split_to_array(line, ','))[8] as label_name
        FROM (
            SELECT unnest(string_to_array(pg_read_file('/home/nitish/Documents/Personal/LabelLift/DesignForRoyalty/RevenueSheet.txt'), E'\n')) AS line
        ) t
        WHERE line NOT LIKE 'service%'
    )
    INSERT INTO whitelabel.song (isrc, title, artist_id, label_id, status)
    SELECT DISTINCT
        d.isrc,
        d.song_name,
        d.userid::integer,
        l.label_id,
        'Released'
    FROM csv_data d
    JOIN whitelabel.label l ON l.label_name = d.label_name
    WHERE d.isrc NOT IN (SELECT isrc FROM whitelabel.song)
    ON CONFLICT (isrc) DO NOTHING;

END;
$$ LANGUAGE plpgsql;

-- Execute the sync function
SELECT sync_revenue_data();

-- Display results
SELECT 'Artists' as type, count(*) as count FROM whitelabel.artist
UNION ALL
SELECT 'Songs' as type, count(*) as count FROM whitelabel.song;
