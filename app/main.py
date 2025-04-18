from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from .api.endpoints import router as analytics_router
from .api.import_endpoints import router as import_router
from .api.csv_endpoints import router as csv_router
from .models.base import ResponseModel

app = FastAPI(
    title="Royalty Analytics API",
    description="API for music royalty analytics and reporting",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Update in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

# Include routers
app.include_router(analytics_router, prefix="/api/v1", tags=["Analytics"])
app.include_router(import_router, prefix="/api/v1/import", tags=["Import"])
app.include_router(csv_router, prefix="/api/v1/import/csv", tags=["CSV Import"])

@app.get("/", response_model=ResponseModel)
async def root():
    """API root endpoint"""
    return ResponseModel(
        success=True,
        message="Welcome to Royalty Analytics API",
        data={
            "version": "1.0.0",
            "documentation": "/docs",
            "redoc": "/redoc"
        }
    )

@app.get("/health", response_model=ResponseModel)
async def health_check():
    """Health check endpoint"""
    try:
        # Add any additional health checks here
        return ResponseModel(
            success=True,
            message="Service is healthy",
            data={
                "status": "UP",
                "timestamp": "utc_timestamp"
            }
        )
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e))
