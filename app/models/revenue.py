from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field

class RevenueOverview(BaseModel):
    """Revenue overview model"""
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

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "year": 2025,
                "month": "Jan",
                "active_artists": 100,
                "active_labels": 10,
                "active_songs": 500,
                "active_platforms": 3,
                "total_plays": 1000000,
                "total_revenue": 50000.00,
                "total_royalties": 35000.00,
                "avg_royalty_rate": 70.00,
                "avg_revenue_per_play": 0.05,
                "earliest_record": "2025-01-01T00:00:00",
                "latest_record": "2025-01-31T23:59:59"
            }
        }

class ArtistPerformance(BaseModel):
    """Artist performance metrics"""
    artist_id: int
    artist_name: str
    label_id: int
    label_name: str
    year: int
    month: str
    songs: Optional[int] = Field(default=None, description="Number of active songs")
    platforms: Optional[int] = Field(default=None, description="Number of platforms")
    plays: int = Field(description="Total play count")
    revenue: float = Field(description="Total revenue earned")
    royalty: float = Field(description="Total royalties earned")
    royalty_percentage: float = Field(description="Royalty percentage")

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "artist_id": 48,
                "artist_name": "Amrit Nagra",
                "label_id": 1,
                "label_name": "Abhi",
                "year": 2025,
                "month": "Jan",
                "songs": 5,
                "platforms": 3,
                "plays": 50000,
                "revenue": 2500.00,
                "royalty": 1750.00,
                "royalty_percentage": 70.00
            }
        }

class PlatformMetrics(BaseModel):
    """Platform performance metrics"""
    platform_name: str
    revenue_share_percentage: float
    year: int
    month: str
    unique_songs: int
    unique_artists: int
    unique_labels: int
    unique_isrcs: int
    total_plays: int
    total_revenue: float
    total_royalties: float
    earliest_record: datetime
    latest_record: datetime

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "platform_name": "Apple",
                "revenue_share_percentage": 70.00,
                "year": 2025,
                "month": "Jan",
                "unique_songs": 1000,
                "unique_artists": 100,
                "unique_labels": 10,
                "unique_isrcs": 1000,
                "total_plays": 500000,
                "total_revenue": 25000.00,
                "total_royalties": 17500.00,
                "earliest_record": "2025-01-01T00:00:00",
                "latest_record": "2025-01-31T23:59:59"
            }
        }

class PlatformRevenue(BaseModel):
    """Platform-wise revenue breakdown"""
    platform_name: str
    total_plays: int
    total_revenue: float
    total_royalties: float
    unique_tracks: int

class TopArtist(BaseModel):
    """Top performing artist metrics"""
    artist_id: int
    artist_name: str
    total_songs: int
    total_plays: int
    total_revenue: float
    total_royalties: float

class LabelPerformance(BaseModel):
    """Label performance metrics"""
    label_id: int
    label_name: str
    total_artists: int
    total_songs: int
    total_plays: int
    total_revenue: float
    total_royalties: float

class GeographicMetrics(BaseModel):
    """Geographic performance metrics"""
    year: int
    month: str
    isrc: Optional[str]
    song_name: Optional[str]
    artist_name: Optional[str]
    country_code: str
    region: str
    platform_name: str
    total_plays: int
    total_revenue: float
    total_royalties: float

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
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
        }

class PlatformLabelMatrix(BaseModel):
    """Cross-analysis of artists across platforms and labels"""
    year: int
    month: str
    artist_id: Optional[int]
    artist_name: Optional[str]
    platform_name: str
    label_name: str
    unique_songs: int
    total_plays: int
    total_revenue: float
    total_royalties: float

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
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
        }
