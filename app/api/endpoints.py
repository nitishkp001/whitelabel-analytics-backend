from fastapi import APIRouter, Depends, HTTPException, Request, Path
from typing import List, Optional
from datetime import datetime
from ..models.base import ResponseModel
from ..models.revenue import (
    RevenueOverview, ArtistPerformance, PlatformMetrics,
    PlatformRevenue, LabelPerformance, TopArtist, GeographicMetrics, PlatformLabelMatrix
)
from ..db.database import get_db, execute_query, execute_one
from ..crud.queries import Queries

router = APIRouter()

def validate_month(month: str) -> str:
    """Validate month format"""
    valid_months = {'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'}
    if month not in valid_months:
        raise HTTPException(status_code=400, detail="Invalid month format")
    return month

def validate_year(year: int) -> int:
    """Validate year range"""
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
        500: {"description": "Internal server error"}
    })
async def get_revenue_overview(
    year: int = Path(..., description="Year (YYYY)", example=2025),
    month: str = Path(..., description="Month (Jan-Dec)", example="Jan")
):
    """Get revenue overview for specified month"""
    try:
        year = validate_year(year)
        month = validate_month(month)
        
        with get_db() as conn:
            # Validate period exists
            exists = execute_one(conn, Queries.validate_month(), {"year": year, "month": month})
            if not exists or not exists['exists']:
                return ResponseModel(
                    success=False,
                    message="No data found for specified period"
                )

            # Get revenue overview
            data = execute_one(conn, Queries.revenue_overview(), {"year": year, "month": month})
            return ResponseModel(
                success=True,
                message="Revenue overview retrieved successfully",
                data=RevenueOverview(**data)
            )

    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/artist/{artist_id}/performance", 
    response_model=ResponseModel,
    responses={
        200: {"description": "Artist performance data retrieved successfully"},
        400: {"description": "Invalid artist ID"},
        404: {"description": "Artist not found"},
        500: {"description": "Internal server error"}
    })
async def get_artist_performance(
    artist_id: int = Path(..., description="Artist ID", example=1, gt=0)
):
    """Get artist performance metrics"""
    try:
        with get_db() as conn:
            # Validate artist exists
            exists = execute_one(conn, Queries.validate_artist(), {"artist_id": artist_id})
            if not exists or not exists['exists']:
                return ResponseModel(
                    success=False,
                    message="Artist not found"
                )

            # Get artist performance
            data = execute_one(conn, Queries.artist_performance(), {"artist_id": artist_id})
            if not data:
                return ResponseModel(
                    success=False,
                    message="No performance data found for artist"
                )

            return ResponseModel(
                success=True,
                message="Artist performance data retrieved successfully",
                data=ArtistPerformance(**data)
            )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/platform/metrics", 
    response_model=ResponseModel,
    responses={
        200: {"description": "Platform metrics retrieved successfully"},
        404: {"description": "No platform metrics available"},
        500: {"description": "Internal server error"}
    })
async def get_platform_metrics():
    """Get performance metrics for all platforms"""
    try:
        with get_db() as conn:
            data = execute_query(conn, Queries.platform_metrics())
            if not data:
                return ResponseModel(
                    success=False,
                    message="No platform metrics available"
                )

            return ResponseModel(
                success=True,
                message="Platform metrics retrieved successfully",
                data=[PlatformMetrics(**row) for row in data]
            )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/artists/{artist_id}/earnings",
    response_model=ResponseModel,
    responses={
        200: {"description": "Artist earnings retrieved successfully"},
        400: {"description": "Invalid artist ID or date parameters"},
        404: {"description": "Artist not found"},
        500: {"description": "Internal server error"}
    })
async def get_artist_earnings(
    artist_id: int = Path(..., description="Artist ID", example=48, gt=0),
    year: Optional[int] = None,
    month: Optional[str] = None
):
    """Get monthly earnings metrics for an artist"""
    try:
        if year:
            year = validate_year(year)
        if month:
            month = validate_month(month)
            
        with get_db() as conn:
            # Validate artist exists
            exists = execute_one(conn, Queries.validate_artist(), {"artist_id": artist_id})
            if not exists or not exists['exists']:
                return ResponseModel(
                    success=False,
                    message="Artist not found"
                )

            # Get artist performance which includes earnings data
            data = execute_one(conn, Queries.artist_performance(), {
                "artist_id": artist_id,
                "year": year,
                "month": month
            })
            if not data:
                return ResponseModel(
                    success=False,
                    message="No earnings data found for artist"
                )

            return ResponseModel(
                success=True,
                message="Artist earnings retrieved successfully",
                data=ArtistPerformance(**data)
            )

    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/platforms/revenue",
    response_model=ResponseModel,
    responses={
        200: {"description": "Platform revenue retrieved successfully"},
        400: {"description": "Invalid date parameters"},
        404: {"description": "No revenue data found"},
        500: {"description": "Internal server error"}
    })
async def get_platform_revenue(
    year: Optional[int] = None,
    month: Optional[str] = None,
    platform_name: Optional[str] = None
):
    """Get revenue breakdown by platform"""
    try:
        if year:
            year = validate_year(year)
        if month:
            month = validate_month(month)
            
        with get_db() as conn:
            data = execute_query(conn, Queries.revenue_by_platform(), {
                "year": year or datetime.now().year,
                "month": month or datetime.now().strftime('%b'),
                "platform_name": platform_name
            })
            if not data:
                return ResponseModel(
                    success=False,
                    message="No revenue data found"
                )

            return ResponseModel(
                success=True,
                message="Platform revenue retrieved successfully",
                data=[PlatformRevenue(**row) for row in data]
            )

    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/labels/performance",
    response_model=ResponseModel,
    responses={
        200: {"description": "Label performance retrieved successfully"},
        400: {"description": "Invalid date parameters"},
        404: {"description": "No performance data found"},
        500: {"description": "Internal server error"}
    })
async def get_label_performance(
    year: Optional[int] = None,
    month: Optional[str] = None,
    label_id: Optional[int] = None
):
    """Get revenue and performance metrics by label"""
    try:
        if year:
            year = validate_year(year)
        if month:
            month = validate_month(month)
            
        with get_db() as conn:
            data = execute_query(conn, Queries.label_performance(), {
                "year": year or datetime.now().year,
                "month": month or datetime.now().strftime('%b'),
                "label_id": label_id
            })
            if not data:
                return ResponseModel(
                    success=False,
                    message="No performance data found"
                )

            return ResponseModel(
                success=True,
                message="Label performance retrieved successfully",
                data=[LabelPerformance(**row) for row in data]
            )

    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/analytics/geography",
    response_model=ResponseModel,
    responses={
        200: {"description": "Geographic analysis retrieved successfully"},
        400: {"description": "Invalid parameters"},
        404: {"description": "No data found"},
        500: {"description": "Internal server error"}
    })
async def get_geographic_analysis(
    year: Optional[int] = None,
    month: Optional[str] = None,
    country_code: Optional[str] = None,
    isrc: Optional[str] = None
):
    """Get revenue and performance metrics by geography"""
    try:
        if year:
            year = validate_year(year)
        if month:
            month = validate_month(month)
        with get_db() as conn:
            from ..models.revenue import GeographicMetrics
            data = execute_query(conn, Queries.geographic_analysis(), {
                "year": year,
                "month": month,
                "country_code": country_code,
                "isrc": isrc
            })
            if not data:
                return ResponseModel(
                    success=False,
                    message="No data found"
                )
            return ResponseModel(
                success=True,
                message="Geographic analysis retrieved successfully",
                data=[GeographicMetrics(**row) for row in data]
            )
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/analytics/platform-label",
    response_model=ResponseModel,
    responses={
        200: {"description": "Platform-label analysis retrieved successfully"},
        400: {"description": "Invalid parameters"},
        404: {"description": "No data found"},
        500: {"description": "Internal server error"}
    })
async def get_platform_label_analysis(
    year: Optional[int] = None,
    month: Optional[str] = None,
    artist_id: Optional[int] = None,
    platform_name: Optional[str] = None,
    label_name: Optional[str] = None
):
    """Get cross-analysis of artists across platforms and labels"""
    try:
        if year:
            year = validate_year(year)
        if month:
            month = validate_month(month)
        with get_db() as conn:
            from ..models.revenue import PlatformLabelMatrix
            data = execute_query(conn, Queries.platform_label_matrix(), {
                "year": year,
                "month": month,
                "artist_id": artist_id,
                "platform_name": platform_name,
                "label_name": label_name
            })
            if not data:
                return ResponseModel(
                    success=False,
                    message="No data found"
                )
            return ResponseModel(
                success=True,
                message="Platform-label analysis retrieved successfully",
                data=[PlatformLabelMatrix(**row) for row in data]
            )
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
