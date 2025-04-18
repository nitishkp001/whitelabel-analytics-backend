from fastapi import APIRouter, HTTPException, Query
from ..models.base import ResponseModel
from ..crud.csv_import import CSVImport
from typing import Optional, Dict

router = APIRouter()

@router.post("/platform/path",
    response_model=ResponseModel,
    responses={
        200: {"description": "Platform configuration imported successfully"},
        400: {"description": "Invalid file path or format"},
        500: {"description": "Internal server error"}
    })
async def import_platform_config(
    file_path: str = Query(..., description="Path to platform configuration CSV file")
):
    """Import platform configuration from CSV file"""
    try:
        result = CSVImport.import_platforms_from_csv(file_path)
        if not result["success"]:
            raise HTTPException(status_code=400, detail=result["message"])
            
        return ResponseModel(
            success=True,
            message=result["message"],
            data={
                "rows_processed": result["rows_processed"],
                "results": result["results"]
            }
        )
        
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/revenue/path",
    response_model=ResponseModel,
    responses={
        200: {"description": "Revenue data imported successfully"},
        400: {"description": "Invalid file path or format"},
        500: {"description": "Internal server error"}
    })
async def import_revenue_data(
    file_path: str = Query(..., description="Path to RevenueSheet.txt file")
):
    """Import revenue data from CSV file"""
    try:
        result = CSVImport.import_revenue_from_csv(file_path)
        if not result["success"]:
            raise HTTPException(status_code=400, detail=result["message"])
            
        return ResponseModel(
            success=True,
            message=result["message"],
            data={
                "rows_processed": result["rows_processed"],
                "processing_stats": result.get("processing_stats", {}),
                "view_refresh": result.get("view_refresh", {})
            }
        )
        
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/validate",
    response_model=ResponseModel,
    responses={
        200: {"description": "File validation completed"},
        400: {"description": "Invalid file path or format"},
        500: {"description": "Internal server error"}
    })
async def validate_csv_file(
    file_path: str = Query(..., description="Path to CSV file to validate"),
    file_type: str = Query(..., description="Type of file (platform/revenue)")
):
    """Validate CSV file format without importing"""
    try:
        if file_type == "platform":
            data = CSVImport.read_platform_csv(file_path)
        elif file_type == "revenue":
            data = CSVImport.read_revenue_csv(file_path)
        else:
            raise HTTPException(status_code=400, detail="Invalid file type")
            
        return ResponseModel(
            success=True,
            message="File validation successful",
            data={
                "rows_found": len(data),
                "sample_row": data[0] if data else None,
                "valid": True
            }
        )
        
    except HTTPException as he:
        raise he
    except Exception as e:
        return ResponseModel(
            success=False,
            message="Validation failed",
            data={
                "error": str(e),
                "valid": False
            }
        )
