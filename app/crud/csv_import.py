import csv
from typing import List, Dict, Any
from datetime import datetime
from pathlib import Path
from .data_import import DataImport

class CSVImport:
    """Handles importing data from CSV files"""

    @staticmethod
    def parse_month_year(month_year_str: str) -> str:
        """Convert Apr/23 format to 2023-04 format"""
        month, year = month_year_str.split('/')
        month_num = datetime.strptime(month, '%b').month
        return f"20{year}-{str(month_num).zfill(2)}"

    @staticmethod
    def read_revenue_csv(file_path: str) -> List[Dict[str, Any]]:
        """
        Read revenue data from CSV file
        Expected CSV format:
        service,month,isrc,product,song_name,artist,album,label,file_name,country,total,royality,userid,id
        """
        revenue_data = []
        file_path = Path(file_path)
        
        if not file_path.exists():
            raise FileNotFoundError(f"CSV file not found: {file_path}")
        
        try:
            with open(file_path, 'r') as csvfile:
                # Skip header line
                next(csvfile)
                
                # Create CSV reader
                reader = csv.reader(csvfile)
                for row in reader:
                    try:
                        # Extract values from CSV row
                        revenue_entry = {
                            "id": row[13],  # UUID
                            "service": row[0],
                            "month": row[1],  # Already in YYYY-MM-DD format
                            "isrc": row[2],
                            "product": row[3],
                            "song_name": row[4],
                            "artist": row[5],
                            "album": row[6],
                            "label": row[7],
                            "file_name": row[8],
                            "country": row[9],
                            "total": float(row[10]),
                            "royalty": float(row[11]),
                            "userid": int(row[12])
                        }
                        revenue_data.append(revenue_entry)
                    except (ValueError, IndexError) as e:
                        print(f"Error processing row: {row}. Error: {e}")
                        continue
                        
        except Exception as e:
            raise Exception(f"Error reading CSV file: {e}")
        
        return revenue_data

    @staticmethod
    def read_platform_csv(file_path: str) -> List[Dict[str, Any]]:
        """
        Read platform configuration from CSV file
        Expected CSV format:
        platform_name,revenue_share_percentage,effective_from
        """
        platform_configs = []
        file_path = Path(file_path)
        
        if not file_path.exists():
            raise FileNotFoundError(f"CSV file not found: {file_path}")
        
        try:
            with open(file_path, 'r') as csvfile:
                reader = csv.DictReader(csvfile)
                for row in reader:
                    try:
                        platform_entry = {
                            "platform_name": row['platform_name'],
                            "revenue_share_percentage": float(row['revenue_share_percentage']),
                            "effective_from": row['effective_from']
                        }
                        platform_configs.append(platform_entry)
                    except (ValueError, KeyError) as e:
                        print(f"Error processing row: {row}. Error: {e}")
                        continue
                        
        except Exception as e:
            raise Exception(f"Error reading CSV file: {e}")
        
        return platform_configs

    @staticmethod
    def import_revenue_from_csv(file_path: str) -> Dict[str, Any]:
        """Import revenue data from CSV file"""
        try:
            # Read CSV file
            revenue_data = CSVImport.read_revenue_csv(file_path)
            if not revenue_data:
                return {
                    "success": False,
                    "message": "No valid data found in CSV file",
                    "rows_processed": 0
                }

            # Stage the data
            success = DataImport.stage_revenue_data(revenue_data)
            if not success:
                return {
                    "success": False,
                    "message": "Failed to stage revenue data",
                    "rows_processed": 0
                }

            # Process the staged data
            stats = DataImport.process_staged_revenue()
            if "ERROR" in stats:
                return {
                    "success": False,
                    "message": f"Error processing data: {stats['ERROR']}",
                    "rows_processed": len(revenue_data)
                }

            # Refresh materialized views
            view_results = DataImport.refresh_materialized_views()
            if not all(view_results.values()):
                return {
                    "success": True,
                    "message": "Data imported but some views failed to refresh",
                    "rows_processed": len(revenue_data),
                    "processing_stats": stats,
                    "view_refresh": view_results
                }

            return {
                "success": True,
                "message": "Revenue data imported successfully",
                "rows_processed": len(revenue_data),
                "processing_stats": stats,
                "view_refresh": view_results
            }

        except Exception as e:
            return {
                "success": False,
                "message": str(e),
                "rows_processed": 0
            }

    @staticmethod
    def import_platforms_from_csv(file_path: str) -> Dict[str, Any]:
        """Import platform configurations from CSV file"""
        try:
            # Read CSV file
            platform_configs = CSVImport.read_platform_csv(file_path)
            if not platform_configs:
                return {
                    "success": False,
                    "message": "No valid data found in CSV file",
                    "rows_processed": 0
                }

            # Import each platform configuration
            results = []
            for config in platform_configs:
                success = DataImport.insert_platform_config(config)
                results.append({
                    "platform": config["platform_name"],
                    "success": success
                })

            successful_imports = sum(1 for r in results if r["success"])
            
            return {
                "success": successful_imports > 0,
                "message": f"Processed {len(results)} platforms, {successful_imports} successful",
                "rows_processed": len(results),
                "results": results
            }

        except Exception as e:
            return {
                "success": False,
                "message": str(e),
                "rows_processed": 0
            }
