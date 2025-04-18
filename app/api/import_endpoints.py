from fastapi import APIRouter, HTTPException, UploadFile, File
from fastapi.responses import JSONResponse
from ..models.base import ResponseModel
from ..crud.csv_import import CSVImport
from typing import Dict

router = APIRouter()

@router.post("/revenue/path", 
    response_model=ResponseModel,
    responses={
        200: {"description": "Revenue data imported successfully"},
        400: {"description": "Invalid file path or format"},
        500: {"description": "Internal server error"}
    })
async def import_revenue_from_path(file_path: str):
    """Import revenue data from a file path"""
    try:
        result = CSVImport.import_revenue_from_csv(file_path)
        if not result["success"]:
            raise HTTPException(status_code=400, detail=result["message"])
            
        return ResponseModel(
            success=True,
            message="Revenue data imported successfully",
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

@router.post("/revenue/file",
    response_model=ResponseModel,
    responses={
        200: {"description": "Revenue data imported successfully"},
        400: {"description": "Invalid file or format"},
        500: {"description": "Internal server error"}
    })
async def import_revenue_file(file: UploadFile = File(...)):
    """Import revenue data from uploaded file"""
    try:
        # Save uploaded file
        temp_path = f"temp_{file.filename}"
        try:
            contents = await file.read()
            with open(temp_path, 'wb') as f:
                f.write(contents)
            
            # Process file
            result = CSVImport.import_revenue_from_csv(temp_path)
            
            if not result["success"]:
                raise HTTPException(status_code=400, detail=result["message"])
                
            return ResponseModel(
                success=True,
                message="Revenue data imported successfully",
                data={
                    "rows_processed": result["rows_processed"],
                    "processing_stats": result.get("processing_stats", {}),
                    "view_refresh": result.get("view_refresh", {})
                }
            )
            
        finally:
            # Clean up temp file
            import os
            if os.path.exists(temp_path):
                os.remove(temp_path)
                
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/status/{job_id}",
    response_model=ResponseModel,
    responses={
        200: {"description": "Import job status retrieved"},
        404: {"description": "Job not found"},
        500: {"description": "Internal server error"}
    })
async def get_import_status(job_id: str):
    """Get status of an import job"""
    try:
        # Mock implementation - replace with actual status tracking
        status = {
            "job_id": job_id,
            "status": "COMPLETED",
            "total_records": 1000,
            "processed": 1000,
            "failed": 0,
            "completed_at": "2025-01-01T12:00:00Z"
        }
        
        return ResponseModel(
            success=True,
            message="Import job status retrieved",
            data=status
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
