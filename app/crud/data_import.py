from typing import List, Dict, Any
from datetime import datetime
from ..db.database import get_db, execute_query

class DataImport:
    """Handles data import and ETL processes"""

    @staticmethod
    def insert_platform_config(platform_data: Dict[str, Any]) -> bool:
        """
        Insert platform configuration
        
        Args:
            platform_data: {
                "platform_name": str,
                "revenue_share_percentage": float,
                "effective_from": str (YYYY-MM-DD)
            }
        """
        query = """
        INSERT INTO platform_config (
            platform_name, 
            revenue_share_percentage, 
            effective_from,
            is_active
        ) VALUES (
            %(platform_name)s, 
            %(revenue_share_percentage)s, 
            %(effective_from)s,
            true
        ) RETURNING platform_id;
        """
        
        try:
            with get_db() as conn:
                with conn.cursor() as cur:
                    cur.execute(query, platform_data)
                    conn.commit()
                    return True
        except Exception as e:
            print(f"Error inserting platform config: {e}")
            return False

    @staticmethod
    def stage_revenue_data(revenue_data: List[Dict[str, Any]]) -> bool:
        """
        Stage revenue data for processing
        
        Args:
            revenue_data: List of {
                "month_year": str (YYYY-MM),
                "platform": str,
                "isrc": str,
                "plays": int,
                "revenue": float,
                "artist_id": int
            }
        """
        query = """
        INSERT INTO analytics.stg_revenue_import (
            id,
            service,
            month,
            isrc,
            product,
            song_name,
            artist,
            album,
            label,
            file_name,
            country,
            total,
            royalty,
            userid,
            status
        ) VALUES (
            %(id)s,
            %(service)s,
            %(month)s::date,
            %(isrc)s,
            %(product)s,
            %(song_name)s,
            %(artist)s,
            %(album)s,
            %(label)s,
            %(file_name)s,
            %(country)s,
            %(total)s,
            %(royalty)s,
            %(userid)s,
            'PENDING'
        );
        """
        
        try:
            with get_db() as conn:
                with conn.cursor() as cur:
                    cur.executemany(query, revenue_data)
                    conn.commit()
                    return True
        except Exception as e:
            print(f"Error staging revenue data: {e}")
            return False

    @staticmethod
    def process_staged_revenue() -> Dict[str, int]:
        """Process staged revenue data"""
        try:
            with get_db() as conn:
                # Call the ETL stored procedure
                with conn.cursor() as cur:
                    cur.execute("CALL analytics.process_revenue_import();")
                    conn.commit()

                # Get processing statistics
                stats_query = """
                SELECT 
                    status,
                    COUNT(*) as count
                FROM analytics.stg_revenue_import
                GROUP BY status;
                """
                stats = execute_query(conn, stats_query)
                
                return {row['status']: row['count'] for row in stats}

        except Exception as e:
            print(f"Error processing revenue data: {e}")
            return {"ERROR": str(e)}

    @staticmethod
    def refresh_materialized_views() -> Dict[str, bool]:
        """Refresh all materialized views"""
        views = [
            'mv_revenue_overview',
            'mv_artist_earnings',
            'mv_platform_revenue',
            'mv_artist_performance',
            'mv_label_performance',
            'mv_artist_platform_label',
            'mv_isrc_geo_platform'
        ]
        
        results = {}
        with get_db() as conn:
            for view in views:
                try:
                    with conn.cursor() as cur:
                        cur.execute(f"REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.{view};")
                        conn.commit()
                        results[view] = True
                except Exception as e:
                    print(f"Error refreshing {view}: {e}")
                    results[view] = False
        
        return results
