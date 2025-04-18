class Queries:
    """SQL queries for analytics"""

    @staticmethod
    def validate_month():
        """Check if data exists for given month"""
        return """
        SELECT EXISTS (
            SELECT 1 
            FROM analytics.fact_monthly_revenue
            WHERE year = %(year)s 
            AND month = %(month)s
        ) as exists;
        """

    @staticmethod
    def validate_artist():
        """Check if artist exists"""
        return """
        SELECT EXISTS (
            SELECT 1 
            FROM whitelabel.artist
            WHERE artist_id = %(artist_id)s
        ) as exists;
        """

    @staticmethod
    def revenue_overview():
        """Get revenue overview for a specific month"""
        return """
        SELECT 
            year,
            month,
            active_artists,
            active_labels,
            active_songs,
            active_platforms,
            total_plays,
            total_revenue,
            total_royalties,
            avg_royalty_rate,
            avg_revenue_per_play,
            earliest_record,
            latest_record
        FROM analytics.mv_revenue_overview
        WHERE year = %(year)s 
        AND month = %(month)s;
        """

    @staticmethod
    def artist_performance():
        """Get artist performance metrics including songs and platforms count"""
        return """
        SELECT 
            a.artist_id,
            a.artist_name,
            l.label_id,
            l.label_name,
            fr.year,
            fr.month,
            COUNT(DISTINCT s.song_id) AS songs,
            COUNT(DISTINCT fr.platform_id) AS platforms,
            SUM(fr.total_plays) AS plays,
            SUM(fr.revenue_amount) AS revenue,
            SUM(fr.royalty_amount) AS royalty,
            ROUND(SUM(fr.royalty_amount) * 100.0 / NULLIF(SUM(fr.revenue_amount), 0), 2) AS royalty_percentage
        FROM analytics.fact_monthly_revenue fr
        JOIN whitelabel.song s ON fr.song_id = s.song_id
        JOIN whitelabel.artist a ON fr.artist_id = a.artist_id
        JOIN whitelabel.label l ON s.label_id = l.label_id
        WHERE a.artist_id = %(artist_id)s
        GROUP BY a.artist_id, a.artist_name, l.label_id, l.label_name, fr.year, fr.month
        ORDER BY fr.year DESC, fr.month DESC
        LIMIT 1;
        """

    @staticmethod
    def platform_metrics():
        """Get platform performance metrics"""
        return """
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
            earliest_record,
            latest_record
        FROM analytics.mv_platform_analytics
        WHERE year = EXTRACT(YEAR FROM CURRENT_DATE)
        AND month = TO_CHAR(CURRENT_DATE, 'Mon');
        """

    @staticmethod
    def revenue_by_platform():
        """Get revenue data by platform"""
        return """
        SELECT 
            pc.platform_name,
            SUM(fr.total_plays) as total_plays,
            SUM(fr.revenue_amount) as total_revenue,
            SUM(fr.royalty_amount) as total_royalties,
            COUNT(DISTINCT ws.isrc) as unique_tracks
        FROM analytics.fact_monthly_revenue fr
        JOIN analytics.platform_config pc ON fr.platform_id = pc.platform_id
        JOIN whitelabel.song ws ON fr.song_id = ws.song_id
        WHERE fr.year = %(year)s
        AND fr.month = %(month)s
        GROUP BY pc.platform_name;
        """

    @staticmethod
    def top_artists():
        """Get top performing artists"""
        return """
        SELECT 
            wa.artist_id,
            wa.artist_name,
            COUNT(DISTINCT ws.song_id) as total_songs,
            SUM(fr.total_plays) as total_plays,
            SUM(fr.revenue_amount) as total_revenue,
            SUM(fr.royalty_amount) as total_royalties
        FROM analytics.fact_monthly_revenue fr
        JOIN whitelabel.song ws ON fr.song_id = ws.song_id
        JOIN whitelabel.artist wa ON ws.artist_id = wa.artist_id
        WHERE fr.year = %(year)s
        AND fr.month = %(month)s
        GROUP BY wa.artist_id, wa.artist_name
        ORDER BY total_revenue DESC
        LIMIT 10;
        """

    @staticmethod
    def label_performance():
        """Get label performance metrics"""
        return """
        SELECT 
            wl.label_id,
            wl.label_name,
            COUNT(DISTINCT ws.artist_id) as total_artists,
            COUNT(DISTINCT ws.song_id) as total_songs,
            SUM(fr.total_plays) as total_plays,
            SUM(fr.revenue_amount) as total_revenue,
            SUM(fr.royalty_amount) as total_royalties
        FROM analytics.fact_monthly_revenue fr
        JOIN whitelabel.song ws ON fr.song_id = ws.song_id
        JOIN whitelabel.label wl ON ws.label_id = wl.label_id
        WHERE fr.year = %(year)s
        AND fr.month = %(month)s
        GROUP BY wl.label_id, wl.label_name
        ORDER BY total_revenue DESC;
        """

    @staticmethod
    def geographic_analysis():
        """Get revenue and performance metrics by geography"""
        return """
        SELECT 
            fr.year,
            fr.month,
            s.isrc,
            s.title AS song_name,
            a.artist_name,
            g.country_code,
            g.region,
            p.platform_name,
            SUM(fr.total_plays) AS total_plays,
            SUM(fr.revenue_amount) AS total_revenue,
            SUM(fr.royalty_amount) AS total_royalties
        FROM analytics.fact_monthly_revenue fr
        JOIN whitelabel.song s ON fr.song_id = s.song_id
        JOIN whitelabel.artist a ON fr.artist_id = a.artist_id
        JOIN analytics.dim_geography g ON fr.geography_id = g.geography_id
        JOIN analytics.platform_config p ON fr.platform_id = p.platform_id
        WHERE fr.year = COALESCE(%(year)s::int, fr.year)
          AND fr.month = COALESCE(%(month)s::varchar, fr.month)
          AND g.country_code = COALESCE(%(country_code)s::varchar, g.country_code)
          AND s.isrc = COALESCE(%(isrc)s::varchar, s.isrc)
        GROUP BY fr.year, fr.month, s.isrc, s.title, a.artist_name, g.country_code, g.region, p.platform_name
        ORDER BY total_revenue DESC;
        """

    @staticmethod
    def platform_label_matrix():
        """Get revenue, plays, and royalty by platform and label, including year, month, artist, and unique_songs for model compatibility"""
        return """
        SELECT
            fr.year,
            fr.month,
            p.platform_name,
            l.label_id,
            l.label_name,
            a.artist_id,
            a.artist_name,
            COUNT(DISTINCT s.song_id) AS unique_songs,
            SUM(fr.total_plays) AS total_plays,
            SUM(fr.revenue_amount) AS total_revenue,
            SUM(fr.royalty_amount) AS total_royalties
        FROM analytics.fact_monthly_revenue fr
        JOIN whitelabel.song s ON fr.song_id = s.song_id
        JOIN whitelabel.label l ON s.label_id = l.label_id
        JOIN analytics.platform_config p ON fr.platform_id = p.platform_id
        JOIN whitelabel.artist a ON fr.artist_id = a.artist_id
        GROUP BY fr.year, fr.month, p.platform_name, l.label_id, l.label_name, a.artist_id, a.artist_name
        ORDER BY total_revenue DESC;
        """
