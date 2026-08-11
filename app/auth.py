from fastapi import Header, HTTPException

from app.config import settings


async def verify_token(authorization: str = Header(...)):
    """Verify the Bearer token from the request header."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header format. Use: Bearer <token>")
    token = authorization[len("Bearer "):]
    if token != settings.api_token:
        raise HTTPException(status_code=401, detail="Invalid API token")
