import os
from app.main import app
import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=os.getenv("API_HOST", "0.0.0.0"),
        port=int(os.getenv("API_PORT", "8000")),
        reload=bool(os.getenv("DEBUG", "True")),
        workers=int(os.getenv("API_WORKERS", "1"))
    )
