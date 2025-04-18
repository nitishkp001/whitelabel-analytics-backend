from typing import Optional, TypeVar, Generic, Dict, Any
from pydantic import BaseModel

T = TypeVar('T')

class ResponseModel(BaseModel, Generic[T]):
    """Base response model for all API endpoints"""
    success: bool
    message: str
    data: Optional[T] = None
    meta: Optional[Dict[str, Any]] = None

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "success": True,
                "message": "Operation completed successfully",
                "data": None,
                "meta": {
                    "total_count": 0,
                    "page": 1,
                    "limit": 10
                }
            }
        }
